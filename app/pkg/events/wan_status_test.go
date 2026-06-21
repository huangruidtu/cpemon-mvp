package events

import (
	"encoding/json"
	"testing"
	"time"

	"github.com/huangruidtu/cpemon-mvp/app/pkg/model"
)

func TestNewWANStatusEventMapsIngestEvent(t *testing.T) {
	eventTS := time.Date(2026, 6, 21, 10, 30, 0, 0, time.UTC)
	receivedAt := time.Date(2026, 6, 21, 10, 31, 0, 0, time.UTC)

	got, err := NewWANStatusEvent(model.IngestEvent{
		Source:  "acs",
		SN:      " CPE-001 ",
		EventTS: eventTS,
		Payload: []byte(`{"wan_ip":"10.0.0.13","wan_status":"up","sw_version":"v1.0-demo"}`),
	}, receivedAt)
	if err != nil {
		t.Fatalf("NewWANStatusEvent returned error: %v", err)
	}

	if got.Topic() != WANStatusTopic {
		t.Fatalf("topic = %q, want %q", got.Topic(), WANStatusTopic)
	}
	if got.Key() != "CPE-001" {
		t.Fatalf("key = %q, want CPE-001", got.Key())
	}
	if got.SchemaVersion != WANStatusSchemaVersion {
		t.Fatalf("schema version = %q, want %q", got.SchemaVersion, WANStatusSchemaVersion)
	}
	if got.EventType != WANStatusEventType {
		t.Fatalf("event type = %q, want %q", got.EventType, WANStatusEventType)
	}
	if got.DeviceID != "CPE-001" || got.SerialNumber != "CPE-001" {
		t.Fatalf("device identity mismatch: device_id=%q serial_number=%q", got.DeviceID, got.SerialNumber)
	}
	if got.WANStatus != "up" {
		t.Fatalf("wan_status = %q, want up", got.WANStatus)
	}
	if got.WANIP != "10.0.0.13" {
		t.Fatalf("wan_ip = %q, want 10.0.0.13", got.WANIP)
	}
	if got.SoftwareVersion != "v1.0-demo" {
		t.Fatalf("sw_version = %q, want v1.0-demo", got.SoftwareVersion)
	}
}

func TestNewWANStatusEventDerivesUpStatusFromWANIP(t *testing.T) {
	got, err := NewWANStatusEvent(model.IngestEvent{
		Source:  "acs",
		SN:      "CPE-001",
		EventTS: time.Now(),
		Payload: []byte(`{"wan_ip":"10.0.0.13"}`),
	}, time.Now())
	if err != nil {
		t.Fatalf("NewWANStatusEvent returned error: %v", err)
	}
	if got.WANStatus != WANStatusUp {
		t.Fatalf("wan_status = %q, want %q", got.WANStatus, WANStatusUp)
	}
}

func TestNewWANStatusEventRejectsMissingWANData(t *testing.T) {
	_, err := NewWANStatusEvent(model.IngestEvent{
		Source:  "acs",
		SN:      "CPE-001",
		EventTS: time.Now(),
		Payload: []byte(`{"sw_version":"v1.0-demo"}`),
	}, time.Now())
	if err == nil {
		t.Fatal("expected error for missing WAN status data")
	}
}

func TestNewWANStatusEventRejectsInvalidJSONPayload(t *testing.T) {
	_, err := NewWANStatusEvent(model.IngestEvent{
		Source:  "acs",
		SN:      "CPE-001",
		EventTS: time.Now(),
		Payload: []byte(`not-json`),
	}, time.Now())
	if err == nil {
		t.Fatal("expected error for invalid JSON payload")
	}
}

func TestWANStatusEventJSONContract(t *testing.T) {
	got, err := NewWANStatusEvent(model.IngestEvent{
		Source:  "acs",
		SN:      "CPE-001",
		EventTS: time.Date(2026, 6, 21, 10, 30, 0, 0, time.UTC),
		Payload: []byte(`{"wan_ip":"10.0.0.13","wan_state":"up"}`),
	}, time.Date(2026, 6, 21, 10, 31, 0, 0, time.UTC))
	if err != nil {
		t.Fatalf("NewWANStatusEvent returned error: %v", err)
	}

	data, err := json.Marshal(got)
	if err != nil {
		t.Fatalf("json.Marshal returned error: %v", err)
	}

	var decoded map[string]any
	if err := json.Unmarshal(data, &decoded); err != nil {
		t.Fatalf("json.Unmarshal returned error: %v", err)
	}

	required := map[string]string{
		"schema_version": "v1",
		"event_type":     "wan.status",
		"source":         "acs",
		"device_id":      "CPE-001",
		"serial_number":  "CPE-001",
		"wan_status":     "up",
		"wan_ip":         "10.0.0.13",
	}
	for key, want := range required {
		if decoded[key] != want {
			t.Fatalf("%s = %v, want %q", key, decoded[key], want)
		}
	}
	if decoded["event_ts"] == "" || decoded["received_at"] == "" {
		t.Fatalf("expected event_ts and received_at in JSON payload: %s", string(data))
	}
}

