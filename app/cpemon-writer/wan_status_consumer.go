package main

import (
	"context"
	"encoding/json"
	"errors"
	"fmt"
	"strings"
	"time"

	"github.com/huangruidtu/cpemon-mvp/app/pkg/events"
)

type wanStatusWrite struct {
	SN              string
	LastSeen        time.Time
	WANStatus       string
	WANIP           *string
	SoftwareVersion *string
}

func decodeWANStatusWrite(event events.ConsumedEvent) (wanStatusWrite, error) {
	if event.Topic != events.WANStatusTopic {
		return wanStatusWrite{}, fmt.Errorf("wan status consumer received unexpected topic %q", event.Topic)
	}
	if len(event.Value) == 0 {
		return wanStatusWrite{}, errors.New("wan status payload is empty")
	}

	var payload events.WANStatusEvent
	if err := json.Unmarshal(event.Value, &payload); err != nil {
		return wanStatusWrite{}, fmt.Errorf("decode wan status payload: %w", err)
	}

	if payload.SchemaVersion != events.WANStatusSchemaVersion {
		return wanStatusWrite{}, fmt.Errorf("wan status schema_version=%q, want %q", payload.SchemaVersion, events.WANStatusSchemaVersion)
	}
	if payload.EventType != events.WANStatusEventType {
		return wanStatusWrite{}, fmt.Errorf("wan status event_type=%q, want %q", payload.EventType, events.WANStatusEventType)
	}

	sn := strings.TrimSpace(payload.SerialNumber)
	if sn == "" {
		sn = strings.TrimSpace(payload.DeviceID)
	}
	if sn == "" {
		return wanStatusWrite{}, errors.New("wan status device identity is required")
	}
	if event.Key != "" && event.Key != sn {
		return wanStatusWrite{}, fmt.Errorf("wan status key %q does not match device identity %q", event.Key, sn)
	}

	wanStatus := strings.TrimSpace(payload.WANStatus)
	if wanStatus == "" {
		return wanStatusWrite{}, errors.New("wan status is required")
	}
	if payload.EventTS.IsZero() {
		return wanStatusWrite{}, errors.New("wan status event_ts is required")
	}

	return wanStatusWrite{
		SN:              sn,
		LastSeen:        payload.EventTS.UTC(),
		WANStatus:       wanStatus,
		WANIP:           optionalString(payload.WANIP),
		SoftwareVersion: optionalString(payload.SoftwareVersion),
	}, nil
}

func writeWANStatus(ctx context.Context, exec sqlExecutor, write wanStatusWrite) error {
	if exec == nil {
		return errors.New("wan status writer requires database executor")
	}
	if strings.TrimSpace(write.SN) == "" {
		return errors.New("wan status write requires serial number")
	}
	if write.LastSeen.IsZero() {
		return errors.New("wan status write requires last_seen")
	}
	if strings.TrimSpace(write.WANStatus) == "" {
		return errors.New("wan status write requires wan status")
	}

	if _, err := exec.ExecContext(ctx, `
INSERT INTO cpe_status (
  sn, last_seen, wan_ip, sw_version, updated_at
) VALUES (
  ?, ?, ?, ?, NOW()
)
ON DUPLICATE KEY UPDATE
  wan_ip = CASE
    WHEN VALUES(wan_ip) IS NOT NULL AND (last_seen IS NULL OR VALUES(last_seen) >= last_seen) THEN VALUES(wan_ip)
    ELSE wan_ip
  END,
  sw_version = CASE
    WHEN VALUES(sw_version) IS NOT NULL AND (last_seen IS NULL OR VALUES(last_seen) >= last_seen) THEN VALUES(sw_version)
    ELSE sw_version
  END,
  last_seen = CASE
    WHEN last_seen IS NULL OR VALUES(last_seen) >= last_seen THEN VALUES(last_seen)
    ELSE last_seen
  END,
  updated_at = NOW()
`, write.SN, write.LastSeen, write.WANIP, write.SoftwareVersion); err != nil {
		return fmt.Errorf("upsert wan status cpe_status: %w", err)
	}

	if _, err := exec.ExecContext(ctx, `
INSERT INTO cpe_status_history (
  sn, event_ts, last_seen, wan_ip, sw_version
) VALUES (
  ?, ?, ?, ?, ?
)
ON DUPLICATE KEY UPDATE
  last_seen = VALUES(last_seen),
  wan_ip = COALESCE(VALUES(wan_ip), wan_ip),
  sw_version = COALESCE(VALUES(sw_version), sw_version)
`, write.SN, write.LastSeen, write.LastSeen, write.WANIP, write.SoftwareVersion); err != nil {
		return fmt.Errorf("insert wan status cpe_status_history: %w", err)
	}

	return nil
}

func processWANStatusConsumedEvent(ctx context.Context, exec sqlExecutor, event events.ConsumedEvent) error {
	write, err := decodeWANStatusWrite(event)
	if err != nil {
		return err
	}
	return writeWANStatus(ctx, exec, write)
}

func optionalString(value string) *string {
	trimmed := strings.TrimSpace(value)
	if trimmed == "" {
		return nil
	}
	return &trimmed
}
