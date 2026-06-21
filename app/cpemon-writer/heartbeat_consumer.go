package main

import (
	"context"
	"database/sql"
	"encoding/json"
	"errors"
	"fmt"
	"strings"
	"time"

	"github.com/huangruidtu/cpemon-mvp/app/pkg/events"
)

type sqlExecutor interface {
	ExecContext(ctx context.Context, query string, args ...any) (sql.Result, error)
}

type heartbeatWrite struct {
	SN       string
	LastSeen time.Time
}

func decodeHeartbeatWrite(event events.ConsumedEvent) (heartbeatWrite, error) {
	if event.Topic != events.DeviceHeartbeatTopic {
		return heartbeatWrite{}, fmt.Errorf("heartbeat consumer received unexpected topic %q", event.Topic)
	}
	if len(event.Value) == 0 {
		return heartbeatWrite{}, errors.New("heartbeat payload is empty")
	}

	var payload events.DeviceHeartbeatEvent
	if err := json.Unmarshal(event.Value, &payload); err != nil {
		return heartbeatWrite{}, fmt.Errorf("decode heartbeat payload: %w", err)
	}

	if payload.SchemaVersion != events.DeviceHeartbeatSchemaVersion {
		return heartbeatWrite{}, fmt.Errorf("heartbeat schema_version=%q, want %q", payload.SchemaVersion, events.DeviceHeartbeatSchemaVersion)
	}
	if payload.EventType != events.DeviceHeartbeatEventType {
		return heartbeatWrite{}, fmt.Errorf("heartbeat event_type=%q, want %q", payload.EventType, events.DeviceHeartbeatEventType)
	}
	if payload.Status == "" {
		return heartbeatWrite{}, errors.New("heartbeat status is required")
	}

	sn := strings.TrimSpace(payload.SerialNumber)
	if sn == "" {
		sn = strings.TrimSpace(payload.DeviceID)
	}
	if sn == "" {
		return heartbeatWrite{}, errors.New("heartbeat device identity is required")
	}
	if event.Key != "" && event.Key != sn {
		return heartbeatWrite{}, fmt.Errorf("heartbeat key %q does not match device identity %q", event.Key, sn)
	}
	if payload.EventTS.IsZero() {
		return heartbeatWrite{}, errors.New("heartbeat event_ts is required")
	}

	return heartbeatWrite{
		SN:       sn,
		LastSeen: payload.EventTS.UTC(),
	}, nil
}

func writeHeartbeatStatus(ctx context.Context, exec sqlExecutor, write heartbeatWrite) error {
	if exec == nil {
		return errors.New("heartbeat writer requires database executor")
	}
	if strings.TrimSpace(write.SN) == "" {
		return errors.New("heartbeat write requires serial number")
	}
	if write.LastSeen.IsZero() {
		return errors.New("heartbeat write requires last_seen")
	}

	if _, err := exec.ExecContext(ctx, `
INSERT INTO cpe_status (
  sn, last_seen, updated_at
) VALUES (
  ?, ?, NOW()
)
ON DUPLICATE KEY UPDATE
  last_seen = CASE
    WHEN last_seen IS NULL OR VALUES(last_seen) >= last_seen THEN VALUES(last_seen)
    ELSE last_seen
  END,
  updated_at = NOW()
`, write.SN, write.LastSeen); err != nil {
		return fmt.Errorf("upsert heartbeat cpe_status: %w", err)
	}

	if _, err := exec.ExecContext(ctx, `
INSERT INTO cpe_status_history (
  sn, event_ts, last_seen
) VALUES (
  ?, ?, ?
)
ON DUPLICATE KEY UPDATE
  last_seen = VALUES(last_seen)
`, write.SN, write.LastSeen, write.LastSeen); err != nil {
		return fmt.Errorf("insert heartbeat cpe_status_history: %w", err)
	}

	return nil
}

func processHeartbeatConsumedEvent(ctx context.Context, exec sqlExecutor, event events.ConsumedEvent) error {
	write, err := decodeHeartbeatWrite(event)
	if err != nil {
		return err
	}
	return writeHeartbeatStatus(ctx, exec, write)
}
