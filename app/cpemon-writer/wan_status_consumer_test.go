package main

import (
	"context"
	"errors"
	"strings"
	"testing"
	"time"

	"github.com/huangruidtu/cpemon-mvp/app/pkg/events"
)

func TestDecodeWANStatusWrite(t *testing.T) {
	eventTS := time.Date(2026, 6, 22, 11, 0, 0, 0, time.UTC)
	event := events.ConsumedEvent{
		Topic: events.WANStatusTopic,
		Key:   "CPE-001",
		Value: []byte(`{
			"schema_version":"v1",
			"event_type":"wan.status",
			"source":"acs",
			"device_id":"CPE-001",
			"serial_number":"CPE-001",
			"event_ts":"2026-06-22T11:00:00Z",
			"received_at":"2026-06-22T11:00:01Z",
			"wan_status":"up",
			"wan_ip":"10.0.0.13",
			"sw_version":"v1.0-demo"
		}`),
	}

	got, err := decodeWANStatusWrite(event)
	if err != nil {
		t.Fatalf("decodeWANStatusWrite returned error: %v", err)
	}
	if got.SN != "CPE-001" {
		t.Fatalf("SN = %q, want CPE-001", got.SN)
	}
	if !got.LastSeen.Equal(eventTS) {
		t.Fatalf("LastSeen = %s, want %s", got.LastSeen, eventTS)
	}
	if got.WANStatus != "up" {
		t.Fatalf("WANStatus = %q, want up", got.WANStatus)
	}
	if got.WANIP == nil || *got.WANIP != "10.0.0.13" {
		t.Fatalf("WANIP = %#v, want 10.0.0.13", got.WANIP)
	}
	if got.SoftwareVersion == nil || *got.SoftwareVersion != "v1.0-demo" {
		t.Fatalf("SoftwareVersion = %#v, want v1.0-demo", got.SoftwareVersion)
	}
}

func TestDecodeWANStatusWriteRejectsInvalidPayload(t *testing.T) {
	tests := []struct {
		name  string
		event events.ConsumedEvent
		want  string
	}{
		{
			name: "wrong topic",
			event: events.ConsumedEvent{
				Topic: events.DeviceHeartbeatTopic,
				Key:   "CPE-001",
				Value: []byte(`{}`),
			},
			want: "unexpected topic",
		},
		{
			name: "invalid json",
			event: events.ConsumedEvent{
				Topic: events.WANStatusTopic,
				Key:   "CPE-001",
				Value: []byte(`not-json`),
			},
			want: "decode wan status payload",
		},
		{
			name: "missing identity",
			event: events.ConsumedEvent{
				Topic: events.WANStatusTopic,
				Value: []byte(`{"schema_version":"v1","event_type":"wan.status","event_ts":"2026-06-22T11:00:00Z","wan_status":"up"}`),
			},
			want: "device identity",
		},
		{
			name: "missing wan status",
			event: events.ConsumedEvent{
				Topic: events.WANStatusTopic,
				Key:   "CPE-001",
				Value: []byte(`{"schema_version":"v1","event_type":"wan.status","device_id":"CPE-001","event_ts":"2026-06-22T11:00:00Z"}`),
			},
			want: "wan status is required",
		},
		{
			name: "key mismatch",
			event: events.ConsumedEvent{
				Topic: events.WANStatusTopic,
				Key:   "CPE-OTHER",
				Value: []byte(`{"schema_version":"v1","event_type":"wan.status","device_id":"CPE-001","event_ts":"2026-06-22T11:00:00Z","wan_status":"up"}`),
			},
			want: "does not match",
		},
		{
			name: "missing timestamp",
			event: events.ConsumedEvent{
				Topic: events.WANStatusTopic,
				Key:   "CPE-001",
				Value: []byte(`{"schema_version":"v1","event_type":"wan.status","device_id":"CPE-001","wan_status":"up"}`),
			},
			want: "event_ts",
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			_, err := decodeWANStatusWrite(tt.event)
			if err == nil {
				t.Fatal("expected error")
			}
			if !strings.Contains(err.Error(), tt.want) {
				t.Fatalf("error = %q, want it to contain %q", err.Error(), tt.want)
			}
		})
	}
}

func TestWriteWANStatusUsesIdempotentUpserts(t *testing.T) {
	eventTS := time.Date(2026, 6, 22, 11, 0, 0, 0, time.UTC)
	wanIP := "10.0.0.13"
	swVersion := "v1.0-demo"
	exec := &recordedExec{}

	err := writeWANStatus(context.Background(), exec, wanStatusWrite{
		SN:              "CPE-001",
		LastSeen:        eventTS,
		WANStatus:       "up",
		WANIP:           &wanIP,
		SoftwareVersion: &swVersion,
	})
	if err != nil {
		t.Fatalf("writeWANStatus returned error: %v", err)
	}

	if len(exec.calls) != 2 {
		t.Fatalf("exec calls = %d, want 2", len(exec.calls))
	}
	if !strings.Contains(exec.calls[0].query, "INSERT INTO cpe_status") ||
		!strings.Contains(exec.calls[0].query, "wan_ip") ||
		!strings.Contains(exec.calls[0].query, "sw_version") ||
		!strings.Contains(exec.calls[0].query, "ON DUPLICATE KEY UPDATE") {
		t.Fatalf("current status query does not look like WAN upsert: %s", exec.calls[0].query)
	}
	if !strings.Contains(exec.calls[1].query, "INSERT INTO cpe_status_history") ||
		!strings.Contains(exec.calls[1].query, "COALESCE") {
		t.Fatalf("history query does not preserve optional WAN fields: %s", exec.calls[1].query)
	}
}

func TestProcessWANStatusConsumedEventPropagatesDBError(t *testing.T) {
	dbErr := errors.New("db unavailable")
	exec := &recordedExec{err: dbErr}

	err := processWANStatusConsumedEvent(context.Background(), exec, events.ConsumedEvent{
		Topic: events.WANStatusTopic,
		Key:   "CPE-001",
		Value: []byte(`{"schema_version":"v1","event_type":"wan.status","device_id":"CPE-001","event_ts":"2026-06-22T11:00:00Z","wan_status":"up","wan_ip":"10.0.0.13"}`),
	})
	if !errors.Is(err, dbErr) {
		t.Fatalf("error = %v, want wrapped db error", err)
	}
}
