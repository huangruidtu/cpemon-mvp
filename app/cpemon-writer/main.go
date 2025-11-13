package main

import (
	"log"
	"net/http"
	"time"

	"github.com/gin-gonic/gin"
	"github.com/jmoiron/sqlx"
	"github.com/prometheus/client_golang/prometheus"
	"github.com/prometheus/client_golang/prometheus/promhttp"

	appconfig "github.com/huangruidtu/cpemon-mvp/app/pkg/config"
	appdb "github.com/huangruidtu/cpemon-mvp/app/pkg/db"
)

// ingestEventRow represents a minimal view of one row from ingest_events.
type ingestEventRow struct {
	ID       int64     `db:"id"`
	SN       string    `db:"sn"`
	EventTS  time.Time `db:"event_ts"`
	Attempts int       `db:"attempts"`
}

// ---- Prometheus metrics ----

var (
	writerRunsTotal = prometheus.NewCounter(
		prometheus.CounterOpts{
			Name: "cpemon_writer_runs_total",
			Help: "Total number of writer loop runs.",
		},
	)

	writerEventsProcessedTotal = prometheus.NewCounter(
		prometheus.CounterOpts{
			Name: "cpemon_writer_events_processed_total",
			Help: "Total number of ingest_events successfully processed by cpemon-writer.",
		},
	)

	writerEventsFailedTotal = prometheus.NewCounterVec(
		prometheus.CounterOpts{
			Name: "cpemon_writer_events_failed_total",
			Help: "Total number of ingest_events failed to process, labeled by reason.",
		},
		[]string{"reason"},
	)

	writerEventsDeadTotal = prometheus.NewCounter(
		prometheus.CounterOpts{
			Name: "cpemon_writer_events_dead_total",
			Help: "Total number of ingest_events marked as dead after too many attempts.",
		},
	)
)

// maxAttempts defines how many times we will retry a failed event
// before marking it as dead.
const maxAttempts = 5

// backoffDuration calculates exponential backoff based on attempts.
// attempts 是当前已经尝试的次数（从 0 开始计）。
func backoffDuration(attempts int) time.Duration {
	base := 5 * time.Second
	maxDelay := 5 * time.Minute

	// attempts: 0 -> 5s, 1 -> 10s, 2 -> 20s, 3 -> 40s, ...
	delay := base * time.Duration(1<<attempts)
	if delay > maxDelay {
		return maxDelay
	}
	return delay
}

func main() {
	// 1. 加载配置（DBDSN, HTTPAddr, WorkerInterval, BatchSize）
	cfg := appconfig.Load()

	// 2. 初始化数据库连接
	if err := appdb.Init(cfg.DBDSN); err != nil {
		log.Fatalf("failed to initialize database: %v", err)
	}

	db := appdb.Get()
	if db == nil {
		log.Fatalf("database not initialized")
	}

	// 3. 注册 Prometheus 指标
	prometheus.MustRegister(
		writerRunsTotal,
		writerEventsProcessedTotal,
		writerEventsFailedTotal,
		writerEventsDeadTotal,
	)

	// 4. 启动后台 worker 循环
	go func() {
		log.Printf("cpemon-writer worker loop started: interval=%s batchSize=%d", cfg.WorkerInterval, cfg.BatchSize)
		ticker := time.NewTicker(cfg.WorkerInterval)
		defer ticker.Stop()

		for range ticker.C {
			writerRunsTotal.Inc()
			if err := runOnce(cfg.BatchSize); err != nil {
				log.Printf("cpemon-writer runOnce error: %v", err)
			}
		}
	}()

	// 5. 暴露 /healthz 和 /metrics
	r := gin.Default()

	// /healthz: 简单返回 ok
	r.GET("/healthz", func(c *gin.Context) {
		c.JSON(http.StatusOK, gin.H{
			"status":  "ok",
			"service": "cpemon-writer",
		})
	})

	// /metrics: 暴露 Prometheus 指标
	r.GET("/metrics", gin.WrapH(promhttp.Handler()))

	log.Printf("cpemon-writer listening on %s\n", cfg.HTTPAddr)
	if err := r.Run(cfg.HTTPAddr); err != nil {
		log.Fatalf("failed to start cpemon-writer: %v", err)
	}
}

// runOnce processes up to batchSize queued events in ingest_events.
// 简化版逻辑：
// 1. 找到 status='queued' & next_at <= NOW() 的事件（LIMIT batchSize）。
// 2. 尝试“锁定”这条事件：UPDATE status='processing', attempts=attempts+1 WHERE id=? AND status='queued'。
//    - 如果行数=0，说明被别人抢到了，跳过。
// 3. 处理事件（当前版本只是打印日志，不更新 cpe_status / history）。
// 4. 成功：UPDATE ingest_events SET status='done', updated_at=NOW() WHERE id=?。
func runOnce(batchSize int) error {
	db := appdb.Get()
	if db == nil {
		return nil
	}

	// 1. 查询待处理事件
	var events []ingestEventRow
	query := `
SELECT
  id, sn, event_ts, attempts
FROM ingest_events
WHERE status = 'queued'
  AND next_at <= NOW()
ORDER BY id
LIMIT ?
`
	if err := db.Select(&events, query, batchSize); err != nil {
		return err
	}

	if len(events) == 0 {
		return nil
	}

	for _, ev := range events {
		if err := processOneEvent(db, &ev); err != nil {
			// 这里只记录日志，具体错误分类和 backoff 在 processOneEvent 里处理
			log.Printf("processOneEvent error for id=%d sn=%s: %v", ev.ID, ev.SN, err)
		}
	}

	return nil
}

// processOneEvent tries to "lock" one event and process it.
//
// 返回 error 仅用于日志记录，真正的重试/标记 dead 逻辑都在里面完成。
func processOneEvent(db *sqlx.DB, ev *ingestEventRow) error {
	// 1. 尝试锁定这条记录：从 queued -> processing，attempts+1
	res, err := db.Exec(`
UPDATE ingest_events
SET status = 'processing',
    attempts = attempts + 1,
    updated_at = NOW()
WHERE id = ?
  AND status = 'queued'
`, ev.ID)
	if err != nil {
		writerEventsFailedTotal.WithLabelValues("lock_error").Inc()
		return err
	}

	rows, err := res.RowsAffected()
	if err != nil {
		writerEventsFailedTotal.WithLabelValues("rows_affected_error").Inc()
		return err
	}
	if rows == 0 {
		// 没抢到锁，说明被别的 writer 处理了，直接跳过即可。
		return nil
	}

	// 2. 模拟处理逻辑
	// 现在我们还没有真正的业务处理（比如写入 cpe_status/history），
	// 为了让队列能跑通，这里先简单打印一条日志，并认为处理成功。
	log.Printf("processing ingest_event id=%d sn=%s event_ts=%s",
		ev.ID, ev.SN, ev.EventTS.Format(time.RFC3339Nano))

	// 3. 当前版本：处理成功，直接标记为 done
	if err := markDone(db, ev.ID); err != nil {
		writerEventsFailedTotal.WithLabelValues("mark_done_error").Inc()
		return err
	}

	writerEventsProcessedTotal.Inc()
	return nil
}

// markDone sets status='done' for event id.
func markDone(db *sqlx.DB, id int64) error {
	_, err := db.Exec(`
UPDATE ingest_events
SET status = 'done',
    updated_at = NOW()
WHERE id = ?
`, id)
	return err
}

// handleFailure updates attempts/next_at/status based on the newAttempts.
// 目前我们还没在流程里真正调用它，预留给以后“业务处理出错时的重试/死信”场景。
func handleFailure(db *sqlx.DB, ev *ingestEventRow, newAttempts int, reason string) error {
	now := time.Now()

	if newAttempts >= maxAttempts {
		// Too many failures: mark as dead.
		_, err := db.Exec(`
UPDATE ingest_events
SET status = 'dead',
    attempts = ?,
    updated_at = ?
WHERE id = ?
`, newAttempts, now, ev.ID)
		if err == nil {
			writerEventsDeadTotal.Inc()
		}
		writerEventsFailedTotal.WithLabelValues(reason).Inc()
		return err
	}

	// Otherwise, schedule a retry with backoff.
	delay := backoffDuration(newAttempts)
	nextAt := now.Add(delay)

	_, err := db.Exec(`
UPDATE ingest_events
SET status = 'queued',
    attempts = ?,
    next_at = ?,
    updated_at = ?
WHERE id = ?
`, newAttempts, nextAt, now, ev.ID)
	if err != nil {
		writerEventsFailedTotal.WithLabelValues("update_retry_state_error").Inc()
	} else {
		writerEventsFailedTotal.WithLabelValues(reason).Inc()
	}
	return err
}
