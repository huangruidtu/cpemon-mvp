package main

import (
	"encoding/json"
	"io"
	"log"
	"net/http"
	"time"

	"github.com/gin-gonic/gin"
	"github.com/prometheus/client_golang/prometheus"
	"github.com/prometheus/client_golang/prometheus/promhttp"

	appconfig "github.com/huangruidtu/cpemon-mvp/app/pkg/config"
	appdb "github.com/huangruidtu/cpemon-mvp/app/pkg/db"
	apphmac "github.com/huangruidtu/cpemon-mvp/app/pkg/hmac"
	"github.com/huangruidtu/cpemon-mvp/app/pkg/model"
	"github.com/huangruidtu/cpemon-mvp/app/pkg/queue"
)

// ---- Prometheus metrics ----

var (
	webhookRequestsTotal = prometheus.NewCounterVec(
		prometheus.CounterOpts{
			Name: "acs_webhook_requests_total",
			Help: "Total number of ACS webhook requests handled by acs-ingest.",
		},
		[]string{"code"}, // HTTP status code as label
	)

	webhookErrorsTotal = prometheus.NewCounterVec(
		prometheus.CounterOpts{
			Name: "acs_webhook_errors_total",
			Help: "Total number of ACS webhook errors grouped by reason.",
		},
		[]string{"reason"}, // e.g. "invalid_json", "missing_sn", "db_error"
	)
)

// acsWebhookPayload defines the minimal fields we expect from the webhook.
type acsWebhookPayload struct {
	SN      string  `json:"sn"`
	EventTS *string `json:"event_ts,omitempty"`
	// Other fields from ACS can exist in the JSON; we keep them in raw payload.
}

// 独立的 metrics server，监听 :9100
func startMetricsServer() {
	mux := http.NewServeMux()
	mux.Handle("/metrics", promhttp.Handler())

	srv := &http.Server{
		Addr:    ":9100",
		Handler: mux,
	}

	go func() {
		log.Printf("[metrics] starting metrics server on %s", srv.Addr)
		if err := srv.ListenAndServe(); err != nil && err != http.ErrServerClosed {
			log.Printf("[metrics] metrics server error: %v", err)
		}
	}()
}

func main() {
	// 1. Load configuration (from environment variables with defaults).
	cfg := appconfig.Load()

	// 2. Initialize database connection using cfg.DBDSN.
	if err := appdb.Init(cfg.DBDSN); err != nil {
		log.Fatalf("failed to initialize database: %v", err)
	}

	// 3. Register Prometheus metrics.
	prometheus.MustRegister(webhookRequestsTotal, webhookErrorsTotal)

	// 👉 在这里启动 9100 端口的 metrics server
	startMetricsServer()

	// 4. Create Gin router.
	r := gin.Default()

	// 5. Health endpoint for liveness/readiness probes.
	r.GET("/healthz", func(c *gin.Context) {
		c.JSON(http.StatusOK, gin.H{
			"status":  "ok",
			"service": "acs-ingest",
		})
	})

	// 6. Metrics endpoint for Prometheus scraping.
	r.GET("/metrics", gin.WrapH(promhttp.Handler()))

	// 7. ACS webhook endpoint.
	r.POST("/acs/webhook", func(c *gin.Context) {
		handleACSWebhook(c, &cfg)
	})

	log.Printf("acs-ingest listening on %s\n", cfg.HTTPAddr)

	// 8. Start HTTP server on cfg.HTTPAddr (e.g. ":8080").
	if err := r.Run(cfg.HTTPAddr); err != nil {
		log.Fatalf("failed to start acs-ingest: %v", err)
	}
}

// handleACSWebhook processes incoming ACS webhook requests.
//
// 1. Read raw request body.
// 2. Verify HMAC signature (if header is present).
// 3. Parse JSON to extract SN and optional event_ts.
// 4. Build a model.IngestEvent and enqueue it via queue.InsertOrUpdateIngestEvent.
func handleACSWebhook(c *gin.Context, cfg *appconfig.Config) {
	start := time.Now()
	ctx := c.Request.Context()
	db := appdb.Get()

	// Ensure DB is initialized.
	if db == nil {
		webhookErrorsTotal.WithLabelValues("db_not_initialized").Inc()
		webhookRequestsTotal.WithLabelValues("500").Inc()
		c.JSON(http.StatusInternalServerError, gin.H{"error": "database not initialized"})
		return
	}

	// 1. Read raw request body.
	body, err := io.ReadAll(c.Request.Body)
	if err != nil {
		webhookErrorsTotal.WithLabelValues("read_body_error").Inc()
		webhookRequestsTotal.WithLabelValues("400").Inc()
		c.JSON(http.StatusBadRequest, gin.H{"error": "failed to read request body"})
		return
	}

	// 2. Optional: verify HMAC signature if header is present.
	signature := c.GetHeader("X-Signature")
	if signature != "" {
		if !apphmac.VerifySHA256Hex(body, cfg.HMACSecret, signature) {
			webhookErrorsTotal.WithLabelValues("invalid_signature").Inc()
			webhookRequestsTotal.WithLabelValues("401").Inc()
			c.JSON(http.StatusUnauthorized, gin.H{"error": "invalid signature"})
			return
		}
	} else {
		// In early development, we allow missing signature but log it.
		log.Println("warning: X-Signature header missing, skipping HMAC verification")
	}

	// 3. Parse JSON into a minimal payload struct.
	var payload acsWebhookPayload
	if err := json.Unmarshal(body, &payload); err != nil {
		webhookErrorsTotal.WithLabelValues("invalid_json").Inc()
		webhookRequestsTotal.WithLabelValues("400").Inc()
		c.JSON(http.StatusBadRequest, gin.H{"error": "invalid JSON payload"})
		return
	}

	if payload.SN == "" {
		webhookErrorsTotal.WithLabelValues("missing_sn").Inc()
		webhookRequestsTotal.WithLabelValues("400").Inc()
		c.JSON(http.StatusBadRequest, gin.H{"error": "missing sn field"})
		return
	}

	// 4. Determine event timestamp.
	eventTime := time.Now()
	if payload.EventTS != nil && *payload.EventTS != "" {
		// Try to parse event_ts as RFC3339/RFC3339Nano.
		if t, err := time.Parse(time.RFC3339Nano, *payload.EventTS); err == nil {
			eventTime = t
		} else if t, err := time.Parse(time.RFC3339, *payload.EventTS); err == nil {
			eventTime = t
		} else {
			log.Printf("warning: invalid event_ts=%q, falling back to now()", *payload.EventTS)
		}
	}

	// 5. Build the ingest event model.
	ev := &model.IngestEvent{
		Source:  "acs",
		SN:      payload.SN,
		EventTS: eventTime,
		Payload: body, // store full raw JSON payload
		// Status, Attempts, NextAt will be defaulted in InsertOrUpdateIngestEvent
	}

	// 6. Enqueue event into ingest_events table.
	if err := queue.InsertOrUpdateIngestEvent(ctx, db, ev); err != nil {
		webhookErrorsTotal.WithLabelValues("db_error").Inc()
		webhookRequestsTotal.WithLabelValues("500").Inc()
		log.Printf("failed to enqueue ingest event: %v", err)
		c.JSON(http.StatusInternalServerError, gin.H{"error": "failed to enqueue event"})
		return
	}

	duration := time.Since(start)
	log.Printf("enqueued event for SN=%s at %s in %s",
		ev.SN, ev.EventTS.Format(time.RFC3339Nano), duration)

	webhookRequestsTotal.WithLabelValues("202").Inc()
	c.JSON(http.StatusAccepted, gin.H{"status": "queued"})
}
