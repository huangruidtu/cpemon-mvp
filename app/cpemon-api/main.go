package main

import (
	"database/sql"
	"log"
	"net/http"
	"strconv"
	"time"

	"github.com/gin-gonic/gin"
	"github.com/prometheus/client_golang/prometheus"
	"github.com/prometheus/client_golang/prometheus/promhttp"

	appconfig "github.com/huangruidtu/cpemon-mvp/app/pkg/config"
	appdb "github.com/huangruidtu/cpemon-mvp/app/pkg/db"
	"github.com/huangruidtu/cpemon-mvp/app/pkg/model"
)

// ---- Prometheus metrics ----

var (
	apiRequestsTotal = prometheus.NewCounterVec(
		prometheus.CounterOpts{
			Name: "cpemon_api_requests_total",
			Help: "Total number of HTTP requests handled by cpemon-api, labeled by status code.",
		},
		[]string{"code"}, // HTTP status code as label: "200", "400", ...
	)
)

// heartbeatPayload defines the JSON body for /cpe/heartbeat.
type heartbeatPayload struct {
	SN        string  `json:"sn"`                  // required
	LastSeen  *string `json:"last_seen,omitempty"` // optional, RFC3339 time
	WANIP     *string `json:"wan_ip,omitempty"`
	SWVersion *string `json:"sw_version,omitempty"`
	CPUPct    *int    `json:"cpu_pct,omitempty"`
	MemPct    *int    `json:"mem_pct,omitempty"`
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
	// 1. Load configuration (DB_DSN, HTTP_ADDR, etc.)
	cfg := appconfig.Load()

	// 2. Initialize database connection.
	if err := appdb.Init(cfg.DBDSN); err != nil {
		log.Fatalf("failed to initialize database: %v", err)
	}

	// 3. Register Prometheus metrics.
	prometheus.MustRegister(apiRequestsTotal)

	// 👉 启动 9100 metrics server
	startMetricsServer()

	// 4. Create Gin router.
	r := gin.Default()

	// 5. Health endpoint.
	r.GET("/healthz", func(c *gin.Context) {
		apiRequestsTotal.WithLabelValues("200").Inc()
		c.JSON(http.StatusOK, gin.H{
			"status":  "ok",
			"service": "cpemon-api",
		})
	})

	// 6. /metrics for Prometheus scraping.
	r.GET("/metrics", gin.WrapH(promhttp.Handler()))

	// 7. CPE query endpoints.
	r.GET("/api/cpe", handleListCPE)
	r.GET("/api/cpe/:sn", handleGetCPE)

	// 8. Optional: heartbeat endpoint (direct write to cpe_status + history).
	r.POST("/cpe/heartbeat", handleHeartbeat)

	log.Printf("cpemon-api listening on %s\n", cfg.HTTPAddr)

	// 9. Start HTTP server.
	if err := r.Run(cfg.HTTPAddr); err != nil {
		log.Fatalf("failed to start cpemon-api: %v", err)
	}
}

// handleListCPE returns a paginated list of current CPE statuses.
//
// GET /api/cpe?offset=0&limit=50
func handleListCPE(c *gin.Context) {
	db := appdb.Get()
	if db == nil {
		apiRequestsTotal.WithLabelValues("500").Inc()
		c.JSON(http.StatusInternalServerError, gin.H{"error": "database not initialized"})
		return
	}

	// Parse offset & limit from query parameters.
	offsetStr := c.DefaultQuery("offset", "0")
	limitStr := c.DefaultQuery("limit", "50")

	offset, err := strconv.Atoi(offsetStr)
	if err != nil || offset < 0 {
		offset = 0
	}
	limit, err := strconv.Atoi(limitStr)
	if err != nil || limit <= 0 || limit > 500 {
		limit = 50
	}

	var items []model.CPEStatus
	query := `
SELECT
  sn, last_seen, wan_ip, sw_version, cpu_pct, mem_pct, updated_at
FROM cpe_status
ORDER BY sn
LIMIT ? OFFSET ?
`
	if err := db.Select(&items, query, limit, offset); err != nil {
		log.Printf("handleListCPE: db error: %v", err)
		apiRequestsTotal.WithLabelValues("500").Inc()
		c.JSON(http.StatusInternalServerError, gin.H{"error": "database query failed"})
		return
	}

	apiRequestsTotal.WithLabelValues("200").Inc()
	c.JSON(http.StatusOK, gin.H{
		"items":  items,
		"offset": offset,
		"limit":  limit,
	})
}

// handleGetCPE returns the current status of a single CPE by SN.
//
// GET /api/cpe/:sn
func handleGetCPE(c *gin.Context) {
	db := appdb.Get()
	if db == nil {
		apiRequestsTotal.WithLabelValues("500").Inc()
		c.JSON(http.StatusInternalServerError, gin.H{"error": "database not initialized"})
		return
	}

	sn := c.Param("sn")
	if sn == "" {
		apiRequestsTotal.WithLabelValues("400").Inc()
		c.JSON(http.StatusBadRequest, gin.H{"error": "missing sn in path"})
		return
	}

	var status model.CPEStatus
	query := `
SELECT
  sn, last_seen, wan_ip, sw_version, cpu_pct, mem_pct, updated_at
FROM cpe_status
WHERE sn = ?
`
	err := db.Get(&status, query, sn)
	if err == sql.ErrNoRows {
		apiRequestsTotal.WithLabelValues("404").Inc()
		c.JSON(http.StatusNotFound, gin.H{"error": "cpe not found"})
		return
	}
	if err != nil {
		log.Printf("handleGetCPE: db error: %v", err)
		apiRequestsTotal.WithLabelValues("500").Inc()
		c.JSON(http.StatusInternalServerError, gin.H{"error": "database query failed"})
		return
	}

	apiRequestsTotal.WithLabelValues("200").Inc()
	c.JSON(http.StatusOK, status)
}

// handleHeartbeat upserts cpe_status and appends a row into cpe_status_history.
//
// POST /cpe/heartbeat
// Body JSON example:
// {
//   "sn": "CPE123456",
//   "last_seen": "2025-01-01T10:00:00Z",
//   "wan_ip": "1.2.3.4",
//   "sw_version": "v1.0.0",
//   "cpu_pct": 42,
//   "mem_pct": 70
// }
func handleHeartbeat(c *gin.Context) {
	db := appdb.Get()
	if db == nil {
		apiRequestsTotal.WithLabelValues("500").Inc()
		c.JSON(http.StatusInternalServerError, gin.H{"error": "database not initialized"})
		return
	}

	var payload heartbeatPayload
	if err := c.ShouldBindJSON(&payload); err != nil {
		apiRequestsTotal.WithLabelValues("400").Inc()
		c.JSON(http.StatusBadRequest, gin.H{"error": "invalid JSON payload"})
		return
	}
	if payload.SN == "" {
		apiRequestsTotal.WithLabelValues("400").Inc()
		c.JSON(http.StatusBadRequest, gin.H{"error": "missing sn"})
		return
	}

	now := time.Now()

	// Determine last_seen time.
	var lastSeen *time.Time
	if payload.LastSeen != nil && *payload.LastSeen != "" {
		if t, err := time.Parse(time.RFC3339Nano, *payload.LastSeen); err == nil {
			lastSeen = &t
		} else if t, err := time.Parse(time.RFC3339, *payload.LastSeen); err == nil {
			lastSeen = &t
		} else {
			log.Printf("handleHeartbeat: invalid last_seen=%q, falling back to now()", *payload.LastSeen)
			t := now
			lastSeen = &t
		}
	} else {
		// If not provided, treat "now" as last_seen.
		t := now
		lastSeen = &t
	}

	// 1) Upsert into cpe_status (current view).
	_, err := db.Exec(`
INSERT INTO cpe_status (
  sn, last_seen, wan_ip, sw_version, cpu_pct, mem_pct, updated_at
) VALUES (
  ?, ?, ?, ?, ?, ?, NOW()
)
ON DUPLICATE KEY UPDATE
  last_seen = VALUES(last_seen),
  wan_ip = VALUES(wan_ip),
  sw_version = VALUES(sw_version),
  cpu_pct = VALUES(cpu_pct),
  mem_pct = VALUES(mem_pct),
  updated_at = NOW()
`, payload.SN, lastSeen, payload.WANIP, payload.SWVersion, payload.CPUPct, payload.MemPct)
	if err != nil {
		log.Printf("handleHeartbeat: upsert cpe_status error: %v", err)
		apiRequestsTotal.WithLabelValues("500").Inc()
		c.JSON(http.StatusInternalServerError, gin.H{"error": "failed to update cpe_status"})
		return
	}

	// 2) Insert into cpe_status_history (append-only).
	eventTS := now
	_, err = db.Exec(`
INSERT INTO cpe_status_history (
  sn, event_ts, last_seen, wan_ip, sw_version, cpu_pct, mem_pct
) VALUES (
  ?, ?, ?, ?, ?, ?, ?
)
`, payload.SN, eventTS, lastSeen, payload.WANIP, payload.SWVersion, payload.CPUPct, payload.MemPct)
	if err != nil {
		log.Printf("handleHeartbeat: insert cpe_status_history error: %v", err)
		// 这里我们不回滚 cpe_status，简单记录错误即可。
		apiRequestsTotal.WithLabelValues("500").Inc()
		c.JSON(http.StatusInternalServerError, gin.H{"error": "failed to insert cpe_status_history"})
		return
	}

	apiRequestsTotal.WithLabelValues("202").Inc()
	c.JSON(http.StatusAccepted, gin.H{"status": "updated"})
}
