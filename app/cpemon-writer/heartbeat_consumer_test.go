package main

import (
	"context"
	"database/sql"
	"errors"
	"strings"
	"testing"
	"time"

	"github.com/huangruidtu/cpemon-mvp/app/pkg/events"
)

type recordedExec struct {
	calls []execCall
	err   error
}

type execCall struct {
	query string
	args  []any
}

func (e *recordedExec) ExecContext(ctx context.Context, query string, args ...any) (sql.Result, error) {
	if err := ctx.Err(); err != nil {
		return nil, err
	}
	e.calls = append(e.calls, execCall{query: query, args: args})
	if e.err != nil {
		return nil, e.err
	}
	return fakeSQLResult(1), nil
}

type fakeSQLResult int64

func (r fakeSQLResult) LastInsertId() (int64, error) { return 0, nil }
func (r fakeSQLResult) RowsAffected() (int64, error) { return int64(r), nil }

func TestDecodeHeartbeatWrite(t *testing.T) {
	eventTS := time.Date(2026, 6, 22, 10, 0, 0, 0, time.UTC)
	event := events.ConsumedEvent{
		Topic: events.DeviceHeartbeatTopic,
		Key:   "CPE-001",
		Value: []byte(`{
			"schema_version":"v1",
			"event_type":"device.heartbeat",
			"source":"acs",
			"device_id":"CPE-001",
			"serial_number":"CPE-001",
			"event_ts":"2026-06-22T10:00:00Z",
			"received_at":"2026-06-22T10:00:01Z",
			"status":"online"
		}`),
	}

	got, err := decodeHeartbeatWrite(event)
	if err != nil {
		t.Fatalf("decodeHeartbeatWrite returned error: %v", err)
	}
	if got.SN != "CPE-001" {
		t.Fatalf("SN = %q, want CPE-001", got.SN)
	}
	if !got.LastSeen.Equal(eventTS) {
		t.Fatalf("LastSeen = %s, want %s", got.LastSeen, eventTS)
	}
}

func TestDecodeHeartbeatWriteRejectsInvalidPayload(t *testing.T) {
	tests := []struct {
		name  string
		event events.ConsumedEvent
		want  string
	}{
		{
			name: "wrong topic",
			event: events.ConsumedEvent{
				Topic: events.WANStatusTopic,
				Key:   "CPE-001",
				Value: []byte(`{}`),
			},
			want: "unexpected topic",
		},
		{
			name: "invalid json",
			event: events.ConsumedEvent{
				Topic: events.DeviceHeartbeatTopic,
				Key:   "CPE-001",
				Value: []byte(`not-json`),
			},
			want: "decode heartbeat payload",
		},
		{
			name: "missing identity",
			event: events.ConsumedEvent{
				Topic: events.DeviceHeartbeatTopic,
				Value: []byte(`{"schema_version":"v1","event_type":"device.heartbeat","event_ts":"2026-06-22T10:00:00Z","status":"online"}`),
			},
			want: "device identity",
		},
		{
			name: "key mismatch",
			event: events.ConsumedEvent{
				Topic: events.DeviceHeartbeatTopic,
				Key:   "CPE-OTHER",
				Value: []byte(`{"schema_version":"v1","event_type":"device.heartbeat","device_id":"CPE-001","event_ts":"2026-06-22T10:00:00Z","status":"online"}`),
			},
			want: "does not match",
		},
		{
			name: "missing timestamp",
			event: events.ConsumedEvent{
				Topic: events.DeviceHeartbeatTopic,
				Key:   "CPE-001",
				Value: []byte(`{"schema_version":"v1","event_type":"device.heartbeat","device_id":"CPE-001","status":"online"}`),
			},
			want: "event_ts",
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			_, err := decodeHeartbeatWrite(tt.event)
			if err == nil {
				t.Fatal("expected error")
			}
			if !strings.Contains(err.Error(), tt.want) {
				t.Fatalf("error = %q, want it to contain %q", err.Error(), tt.want)
			}
		})
	}
}

func TestWriteHeartbeatStatusUsesIdempotentUpserts(t *testing.T) {
	eventTS := time.Date(2026, 6, 22, 10, 0, 0, 0, time.UTC)
	exec := &recordedExec{}

	err := writeHeartbeatStatus(context.Background(), exec, heartbeatWrite{
		SN:       "CPE-001",
		LastSeen: eventTS,
	})
	if err != nil {
		t.Fatalf("writeHeartbeatStatus returned error: %v", err)
	}

	if len(exec.calls) != 2 {
		t.Fatalf("exec calls = %d, want 2", len(exec.calls))
	}
	if !strings.Contains(exec.calls[0].query, "INSERT INTO cpe_status") ||
		!strings.Contains(exec.calls[0].query, "ON DUPLICATE KEY UPDATE") ||
		!strings.Contains(exec.calls[0].query, "last_seen") {
		t.Fatalf("current status query does not look like idempotent heartbeat upsert: %s", exec.calls[0].query)
	}
	if !strings.Contains(exec.calls[1].query, "INSERT INTO cpe_status_history") ||
		!strings.Contains(exec.calls[1].query, "ON DUPLICATE KEY UPDATE") {
		t.Fatalf("history query does not look idempotent: %s", exec.calls[1].query)
	}
}

func TestProcessHeartbeatConsumedEventPropagatesDBError(t *testing.T) {
	dbErr := errors.New("db unavailable")
	exec := &recordedExec{err: dbErr}

	err := processHeartbeatConsumedEvent(context.Background(), exec, events.ConsumedEvent{
		Topic: events.DeviceHeartbeatTopic,
		Key:   "CPE-001",
		Value: []byte(`{"schema_version":"v1","event_type":"device.heartbeat","device_id":"CPE-001","event_ts":"2026-06-22T10:00:00Z","status":"online"}`),
	})
	if !errors.Is(err, dbErr) {
		t.Fatalf("error = %v, want wrapped db error", err)
	}
}
