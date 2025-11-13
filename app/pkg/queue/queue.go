package queue

import (
	"context"
	"time"

	"github.com/jmoiron/sqlx"

	"github.com/huangruidtu/cpemon-mvp/app/pkg/model"
)

// InsertOrUpdateIngestEvent inserts a new ingest_events row or updates an existing one
// (idempotent enqueue).
func InsertOrUpdateIngestEvent(ctx context.Context, db *sqlx.DB, ev *model.IngestEvent) error {
	// If caller did not set these fields, we set reasonable defaults.
	if ev.Status == "" {
		ev.Status = "queued"
	}
	if ev.Attempts == 0 {
		ev.Attempts = 0
	}
	if ev.NextAt.IsZero() {
		ev.NextAt = time.Now()
	}
	if ev.Source == "" {
		ev.Source = "acs"
	}

	query := `
INSERT INTO ingest_events (
  source, sn, event_ts, payload, status, attempts, next_at
) VALUES (
  :source, :sn, :event_ts, :payload, :status, :attempts, :next_at
)
ON DUPLICATE KEY UPDATE
  payload   = VALUES(payload),
  status    = VALUES(status),
  attempts  = VALUES(attempts),
  next_at   = VALUES(next_at),
  updated_at = NOW()
`
	_, err := db.NamedExecContext(ctx, query, ev)
	return err
}

// FetchReadyBatch returns up to "limit" events which are ready to be processed.
// Simplified: we just select rows with status='queued' and next_at <= now()
// and rely on there being only one writer process in this MVP.
func FetchReadyBatch(ctx context.Context, db *sqlx.DB, limit int) ([]model.IngestEvent, error) {
	if limit <= 0 {
		limit = 50
	}

	query := `
SELECT
  id, source, sn, event_ts, payload, status, attempts, next_at,
  created_at, updated_at
FROM ingest_events
WHERE status = 'queued' AND next_at <= NOW()
ORDER BY id
LIMIT ?
`
	var events []model.IngestEvent
	if err := db.SelectContext(ctx, &events, query, limit); err != nil {
		return nil, err
	}
	return events, nil
}

// MarkDone marks an event as successfully processed.
func MarkDone(ctx context.Context, db *sqlx.DB, id int64) error {
	_, err := db.ExecContext(ctx,
		`UPDATE ingest_events SET status = 'done', updated_at = NOW() WHERE id = ?`,
		id,
	)
	return err
}

// MarkFailedWithBackoff marks an event as failed and schedules it for a retry
// using a simple exponential backoff strategy.
func MarkFailedWithBackoff(ctx context.Context, db *sqlx.DB, ev *model.IngestEvent, baseDelay time.Duration, maxAttempts int) error {
	ev.Attempts++
	if ev.Attempts >= maxAttempts {
		// Give up on this event.
		_, err := db.ExecContext(ctx,
			`UPDATE ingest_events SET status = 'dead', attempts = ?, updated_at = NOW() WHERE id = ?`,
			ev.Attempts, ev.ID,
		)
		return err
	}

	// next_at = now + baseDelay * 2^(attempts-1)
	delay := baseDelay * (1 << (ev.Attempts - 1)) // 1, 2, 4, 8, ...
	nextAt := time.Now().Add(delay)

	_, err := db.ExecContext(ctx,
		`UPDATE ingest_events
         SET status = 'queued', attempts = ?, next_at = ?, updated_at = NOW()
         WHERE id = ?`,
		ev.Attempts, nextAt, ev.ID,
	)

	return err
}
