package main

import (
	"database/sql"
	"fmt"
	"html/template"
	"log"
	"net/http"
	"net/url"
	"os"
	"strconv"
	"strings"
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

	// per-CPE metrics (labeled by SN)
	cpeCPU = prometheus.NewGaugeVec(
		prometheus.GaugeOpts{
			Name: "cpemon_cpe_cpu_pct",
			Help: "CPU usage reported by CPE heartbeat, in percent.",
		},
		[]string{"sn"},
	)

	cpeMem = prometheus.NewGaugeVec(
		prometheus.GaugeOpts{
			Name: "cpemon_cpe_mem_pct",
			Help: "Memory usage reported by CPE heartbeat, in percent.",
		},
		[]string{"sn"},
	)

	cpeHeartbeatTotal = prometheus.NewCounterVec(
		prometheus.CounterOpts{
			Name: "cpemon_cpe_heartbeat_total",
			Help: "Total number of CPE heartbeat events received, labeled by sn.",
		},
		[]string{"sn"},
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

type CPEStatusView struct {
	SN              string
	WANIP           string
	SWVersion       string
	CPUPct          int
	MemPct          int
	LastHeartbeatAt string
}

type CPEHistoryRow struct {
	HeartbeatAt string
	WANIP       string
	CPUPct      int
	MemPct      int
}

// Admin 页面用到的数据结构
type AdminPageData struct {
	SearchSN     string
	ErrorMessage string

	CurrentStatus *CPEStatusView
	History       []CPEHistoryRow

	// Monitoring (Grafana)
	GrafanaHomeURL string
	GrafanaSNURL   string

	// Logs (Kibana)
	KibanaHomeURL string
	KibanaSNURL   string
}

// DB row 映射（只在 admin 用）
type cpeStatusRow struct {
	SN              string
	WANIP           string
	SWVersion       string
	CPUPct          int
	MemPct          int
	LastHeartbeatAt time.Time
}

type cpeHistoryRow struct {
	SN          string
	WANIP       string
	SWVersion   string
	CPUPct      int
	MemPct      int
	HeartbeatAt time.Time
}

// 后面可能用到的 metrics 壳（暂时不用）
type AdminMetricsBlock struct {
	HeartbeatChartURL string
	CPUChartURL       string
	MemChartURL       string
}

// 内嵌 Admin 页面模板
var adminPageTemplate = template.Must(template.New("admin").Parse(`
<!DOCTYPE html>
<html>
<head>
  <meta charset="utf-8" />
  <title>CPEmon Admin</title>
  <style>
    body {
      font-family: sans-serif;
      margin: 0;
      padding: 0;
    }
    .page {
      display: flex;
      flex-direction: column;
      min-height: 100vh;
    }
    .header {
      padding: 16px 24px;
      border-bottom: 1px solid #ddd;
    }
    .content {
      display: flex;
      flex: 1;
      padding: 16px 24px;
      gap: 24px;
    }
    .left-panel {
      flex: 3;
    }
    .right-panel {
      flex: 2;
    }
    .card {
      border: 1px solid #ddd;
      border-radius: 4px;
      padding: 12px 16px;
      margin-bottom: 16px;
    }
    .card h2 {
      margin-top: 0;
    }
    table {
      width: 100%;
      border-collapse: collapse;
    }
    th, td {
      padding: 6px 8px;
      border-bottom: 1px solid #eee;
      text-align: left;
      font-size: 14px;
    }
    .kibana-button {
      display: inline-block;
      padding: 8px 12px;
      border-radius: 4px;
      border: 1px solid #555;
      text-decoration: none;
      font-weight: bold;
    }
  </style>
</head>
<body>
  <div class="page">
    <div class="header">
      <h1>CPEmon Admin</h1>
      <p>Search CPE by SN and view current status, history, and observability links.</p>
    </div>

    <div class="content">
      <!-- 左侧 -->
      <div class="left-panel">
        <!-- 搜索卡片 -->
        <div class="card">
          <h2>Search CPE</h2>
          <form method="GET" action="/admin">
            <label>SN:
              <input type="text" name="sn" value="{{ .SearchSN }}">
            </label>
            <button type="submit">Search</button>
          </form>

          {{ if .ErrorMessage }}
            <p style="color:red;">{{ .ErrorMessage }}</p>
          {{ end }}
        </div>

        <!-- 当前状态卡片 -->
        <div class="card">
          <h2>Current status</h2>
          {{ if .CurrentStatus }}
            <ul>
              <li>SN: {{ .CurrentStatus.SN }}</li>
              <li>WAN IP: {{ .CurrentStatus.WANIP }}</li>
              <li>SW Version: {{ .CurrentStatus.SWVersion }}</li>
              <li>CPU: {{ .CurrentStatus.CPUPct }} %</li>
              <li>Memory: {{ .CurrentStatus.MemPct }} %</li>
              <li>Last heartbeat: {{ .CurrentStatus.LastHeartbeatAt }}</li>
            </ul>
          {{ else }}
            <p>No current status found for this SN.</p>
          {{ end }}
        </div>

        <!-- 历史记录卡片 -->
        <div class="card">
          <h2>Recent history</h2>
          {{ if .History }}
            <table>
              <thead>
                <tr>
                  <th>Time</th>
                  <th>WAN IP</th>
                  <th>CPU %</th>
                  <th>Mem %</th>
                </tr>
              </thead>
              <tbody>
                {{ range .History }}
                  <tr>
                    <td>{{ .HeartbeatAt }}</td>
                    <td>{{ .WANIP }}</td>
                    <td>{{ .CPUPct }}</td>
                    <td>{{ .MemPct }}</td>
                  </tr>
                {{ end }}
              </tbody>
            </table>
          {{ else }}
            <p>No history records found.</p>
          {{ end }}
        </div>
      </div>

      <!-- 右侧 -->
      <div class="right-panel">
        <div class="card">
          <h2>Monitoring (Grafana)</h2>

          {{ if .GrafanaHomeURL }}
            <p>Open the global metrics dashboard in Grafana.</p>
            <p>
              <a class="kibana-button"
                 href="{{ .GrafanaHomeURL }}"
                 target="_blank"
                 rel="noopener noreferrer">
                Open Grafana (home)
              </a>
            </p>
          {{ else }}
            <p>No Grafana home URL configured (GRAFANA_HOME_URL).</p>
          {{ end }}

          {{ if and .SearchSN .GrafanaSNURL }}
            <p style="margin-top: 12px;">
              <strong>Current SN: {{ .SearchSN }}</strong>
            </p>
            <p>
              <a class="kibana-button"
                 href="{{ .GrafanaSNURL }}"
                 target="_blank"
                 rel="noopener noreferrer">
                Open Grafana for this CPE
              </a>
            </p>
          {{ else if .SearchSN }}
            <p style="margin-top: 12px;">SN is set, but no Grafana SN dashboard template configured.</p>
          {{ end }}
        </div>

        <div class="card">
          <h2>Logs</h2>

          {{ if .KibanaHomeURL }}
            <p>Open detailed logs in Kibana.</p>
            <p>
              <a class="kibana-button"
                 href="{{ .KibanaHomeURL }}"
                 target="_blank"
                 rel="noopener noreferrer">
                Open Kibana (home)
              </a>
            </p>
          {{ else }}
            <p>No Kibana home URL configured (KIBANA_HOME_URL).</p>
          {{ end }}

          {{ if and .SearchSN .KibanaSNURL }}
            <p style="margin-top: 12px;">
              <strong>Current SN: {{ .SearchSN }}</strong>
            </p>
            <p>
              <a class="kibana-button"
                 href="{{ .KibanaSNURL }}"
                 target="_blank"
                 rel="noopener noreferrer">
                Open Kibana logs for this CPE
              </a>
            </p>
          {{ else if .SearchSN }}
            <p style="margin-top: 12px;">
              SN is set, but no Kibana SN logs URL template configured.
            </p>
          {{ end }}
        </div>
      </div>
    </div>
  </div>
</body>
</html>
`))

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
	prometheus.MustRegister(apiRequestsTotal, cpeCPU, cpeMem, cpeHeartbeatTotal)

	// 启动 9100 metrics server
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

	// 8. heartbeat endpoint.
	r.POST("/cpe/heartbeat", handleHeartbeat)

	// 9. Admin page
	r.GET("/admin", handleAdmin)

	log.Printf("cpemon-api listening on %s\n", cfg.HTTPAddr)

	// 10. Start HTTP server.
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

// 小工具：把 *int / *string 安全转换
func intOrZero(p *int) int {
	if p == nil {
		return 0
	}
	return *p
}

func stringOrEmpty(p *string) string {
	if p == nil {
		return ""
	}
	return *p
}

// handleHeartbeat upserts cpe_status and appends a row into cpe_status_history.
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

	// --- 更新 per-CPE Prometheus 指标 ---
	labels := []string{payload.SN}

	if payload.CPUPct != nil {
		cpeCPU.WithLabelValues(labels...).Set(float64(*payload.CPUPct))
	}
	if payload.MemPct != nil {
		cpeMem.WithLabelValues(labels...).Set(float64(*payload.MemPct))
	}
	// 不管有没有 CPU/Mem，都统计一次 heartbeat 次数
	cpeHeartbeatTotal.WithLabelValues(labels...).Inc()

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

	// 在日志里打上一行，方便 Kibana 搜索（message 里包含 sn=...）
	log.Printf("heartbeat updated: sn=%s wan_ip=%s sw_version=%s cpu=%d mem=%d",
		payload.SN,
		stringOrEmpty(payload.WANIP),
		stringOrEmpty(payload.SWVersion),
		intOrZero(payload.CPUPct),
		intOrZero(payload.MemPct),
	)

	apiRequestsTotal.WithLabelValues("202").Inc()
	c.JSON(http.StatusAccepted, gin.H{"status": "updated"})
}

func handleAdmin(c *gin.Context) {
	sn := strings.TrimSpace(c.Query("sn"))

	// 1) 初始化页面数据，只先填 SearchSN
	data := AdminPageData{
		SearchSN: sn,
	}

	// 2) 如果有 SN，就查当前状态和历史
	if sn != "" {
		db := appdb.Get()
		if db == nil {
			c.String(http.StatusInternalServerError, "database not initialized")
			return
		}

		// 2.1 查询当前状态
		const qCurrent = `
SELECT sn, wan_ip, sw_version, cpu_pct, mem_pct, last_seen
FROM cpe_status
WHERE sn = ?
`
		var r cpeStatusRow
		err := db.QueryRow(qCurrent, sn).Scan(
			&r.SN,
			&r.WANIP,
			&r.SWVersion,
			&r.CPUPct,
			&r.MemPct,
			&r.LastHeartbeatAt,
		)
		if err != nil {
			if err == sql.ErrNoRows {
				data.ErrorMessage = "SN not found"
			} else {
				log.Printf("handleAdmin: current status query error: %v", err)
				c.String(http.StatusInternalServerError, "database query failed")
				return
			}
		} else {
			data.CurrentStatus = &CPEStatusView{
				SN:              r.SN,
				WANIP:           r.WANIP,
				SWVersion:       r.SWVersion,
				CPUPct:          r.CPUPct,
				MemPct:          r.MemPct,
				LastHeartbeatAt: r.LastHeartbeatAt.Format("2006-01-02 15:04:05"),
			}
		}

		// 2.2 查询历史记录
		const qHistory = `
SELECT sn, wan_ip, sw_version, cpu_pct, mem_pct, event_ts
FROM cpe_status_history
WHERE sn = ?
ORDER BY event_ts DESC
LIMIT 20
`
		rows, err := db.Query(qHistory, sn)
		if err != nil {
			log.Printf("handleAdmin: history query error: %v", err)
			c.String(http.StatusInternalServerError, "database query failed")
			return
		}
		defer rows.Close()

		for rows.Next() {
			var hr cpeHistoryRow
			if err := rows.Scan(
				&hr.SN,
				&hr.WANIP,
				&hr.SWVersion,
				&hr.CPUPct,
				&hr.MemPct,
				&hr.HeartbeatAt,
			); err != nil {
				log.Printf("handleAdmin: history scan error: %v", err)
				c.String(http.StatusInternalServerError, "database query failed")
				return
			}
			data.History = append(data.History, CPEHistoryRow{
				HeartbeatAt: hr.HeartbeatAt.Format("2006-01-02 15:04:05"),
				WANIP:       hr.WANIP,
				CPUPct:      hr.CPUPct,
				MemPct:      hr.MemPct,
			})
		}
		if err := rows.Err(); err != nil {
			log.Printf("handleAdmin: history rows error: %v", err)
			c.String(http.StatusInternalServerError, "database query failed")
			return
		}
	}

	// 3) 设置 Grafana 链接（一定要在渲染模板之前）
	data.GrafanaHomeURL = os.Getenv("GRAFANA_HOME_URL")
	if sn != "" {
		if tpl := os.Getenv("GRAFANA_SN_DASHBOARD_URL_TEMPLATE"); tpl != "" {
			data.GrafanaSNURL = fmt.Sprintf(tpl, url.QueryEscape(sn))
		}
	}

	// 4) 设置 Kibana 链接
	data.KibanaHomeURL = os.Getenv("KIBANA_HOME_URL")
	if sn != "" {
		if tpl := os.Getenv("KIBANA_SN_LOGS_URL_TEMPLATE"); tpl != "" {
			data.KibanaSNURL = fmt.Sprintf(tpl, url.QueryEscape(sn))
		}
	}

	// 5) 渲染模板
	c.Status(http.StatusOK)
	c.Header("Content-Type", "text/html; charset=utf-8")
	if err := adminPageTemplate.Execute(c.Writer, data); err != nil {
		c.String(http.StatusInternalServerError, "template error: %v", err)
		return
	}
}

