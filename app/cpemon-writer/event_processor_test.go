package main

import (
	"context"
	"strings"
	"testing"

	"github.com/huangruidtu/cpemon-mvp/app/pkg/events"
)

func TestProcessConsumedEventRoutesHeartbeatToMySQLWrites(t *testing.T) {
	exec := &recordedExec{}

	err := processConsumedEvent(context.Background(), exec, events.ConsumedEvent{
		Topic: events.DeviceHeartbeatTopic,
		Key:   "CPE-001",
		Value: []byte(`{"schema_version":"v1","event_type":"device.heartbeat","device_id":"CPE-001","event_ts":"2026-06-22T10:00:00Z","status":"online"}`),
	})
	if err != nil {
		t.Fatalf("processConsumedEvent returned error: %v", err)
	}
	if len(exec.calls) != 2 {
		t.Fatalf("exec calls = %d, want 2", len(exec.calls))
	}
	if !strings.Contains(exec.calls[0].query, "cpe_status") ||
		!strings.Contains(exec.calls[1].query, "cpe_status_history") {
		t.Fatalf("heartbeat route did not write expected tables: %#v", exec.calls)
	}
}

func TestProcessConsumedEventRoutesWANStatusToMySQLWrites(t *testing.T) {
	exec := &recordedExec{}

	err := processConsumedEvent(context.Background(), exec, events.ConsumedEvent{
		Topic: events.WANStatusTopic,
		Key:   "CPE-001",
		Value: []byte(`{"schema_version":"v1","event_type":"wan.status","device_id":"CPE-001","event_ts":"2026-06-22T11:00:00Z","wan_status":"up","wan_ip":"10.0.0.13"}`),
	})
	if err != nil {
		t.Fatalf("processConsumedEvent returned error: %v", err)
	}
	if len(exec.calls) != 2 {
		t.Fatalf("exec calls = %d, want 2", len(exec.calls))
	}
	if !strings.Contains(exec.calls[0].query, "wan_ip") ||
		!strings.Contains(exec.calls[1].query, "cpe_status_history") {
		t.Fatalf("WAN route did not write expected fields/tables: %#v", exec.calls)
	}
}

func TestProcessConsumedEventRejectsUnsupportedTopic(t *testing.T) {
	err := processConsumedEvent(context.Background(), &recordedExec{}, events.ConsumedEvent{
		Topic: "cpemon.unknown.v1",
		Key:   "CPE-001",
		Value: []byte(`{}`),
	})
	if err == nil {
		t.Fatal("expected unsupported topic error")
	}
	if !strings.Contains(err.Error(), "unsupported consumed event topic") {
		t.Fatalf("error = %q", err.Error())
	}
}
