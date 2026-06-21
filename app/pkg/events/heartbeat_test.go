package events

import (
	"encoding/json"
	"testing"
	"time"

	"github.com/huangruidtu/cpemon-mvp/app/pkg/model"
)

func TestNewDeviceHeartbeatEventMapsIngestEvent(t *testing.T) {
	eventTS := time.Date(2026, 6, 21, 12, 30, 0, 0, time.FixedZone("UTC+2", 2*60*60))
	receivedAt := time.Date(2026, 6, 21, 10, 31, 0, 0, time.UTC)

	got, err := NewDeviceHeartbeatEvent(model.IngestEvent{
		Source:  "acs",
		SN:      " CPE-001 ",
		EventTS: eventTS,
	}, receivedAt)
	if err != nil {
		t.Fatalf("NewDeviceHeartbeatEvent returned error: %v", err)
	}

	if got.Topic() != DeviceHeartbeatTopic {
		t.Fatalf("topic = %q, want %q", got.Topic(), DeviceHeartbeatTopic)
	}
	if got.Key() != "CPE-001" {
		t.Fatalf("key = %q, want CPE-001", got.Key())
	}
	if got.SchemaVersion != DeviceHeartbeatSchemaVersion {
		t.Fatalf("schema version = %q, want %q", got.SchemaVersion, DeviceHeartbeatSchemaVersion)
	}
	if got.EventType != DeviceHeartbeatEventType {
		t.Fatalf("event type = %q, want %q", got.EventType, DeviceHeartbeatEventType)
	}
	if got.Source != "acs" {
		t.Fatalf("source = %q, want acs", got.Source)
	}
	if got.DeviceID != "CPE-001" || got.SerialNumber != "CPE-001" {
		t.Fatalf("device identity mismatch: device_id=%q serial_number=%q", got.DeviceID, got.SerialNumber)
	}
	if got.EventTS.Location() != time.UTC {
		t.Fatalf("event_ts location = %v, want UTC", got.EventTS.Location())
	}
	if got.Status != DeviceHeartbeatStatusOnline {
		t.Fatalf("status = %q, want %q", got.Status, DeviceHeartbeatStatusOnline)
	}
}

func TestNewDeviceHeartbeatEventRejectsMissingSerialNumber(t *testing.T) {
	_, err := NewDeviceHeartbeatEvent(model.IngestEvent{
		EventTS: time.Now(),
	}, time.Now())
	if err == nil {
		t.Fatal("expected error for missing serial number")
	}
}

func TestNewDeviceHeartbeatEventRejectsMissingEventTimestamp(t *testing.T) {
	_, err := NewDeviceHeartbeatEvent(model.IngestEvent{
		SN: "CPE-001",
	}, time.Now())
	if err == nil {
		t.Fatal("expected error for missing event timestamp")
	}
}

func TestDeviceHeartbeatEventJSONContract(t *testing.T) {
	got, err := NewDeviceHeartbeatEvent(model.IngestEvent{
		Source:  "acs",
		SN:      "CPE-001",
		EventTS: time.Date(2026, 6, 21, 10, 30, 0, 0, time.UTC),
	}, time.Date(2026, 6, 21, 10, 31, 0, 0, time.UTC))
	if err != nil {
		t.Fatalf("NewDeviceHeartbeatEvent returned error: %v", err)
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
		"event_type":     "device.heartbeat",
		"source":         "acs",
		"device_id":      "CPE-001",
		"serial_number":  "CPE-001",
		"status":         "online",
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

