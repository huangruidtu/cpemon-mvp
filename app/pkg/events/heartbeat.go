package events

import (
	"errors"
	"strings"
	"time"

	"github.com/huangruidtu/cpemon-mvp/app/pkg/model"
)

const (
	DeviceHeartbeatTopic         = "cpemon.device.heartbeat.v1"
	DeviceHeartbeatEventType     = "device.heartbeat"
	DeviceHeartbeatSchemaVersion = "v1"
	DeviceHeartbeatStatusOnline  = "online"
)

// DeviceHeartbeatEvent is the normalized Kafka event emitted by acs-ingest
// when a device heartbeat is observed.
type DeviceHeartbeatEvent struct {
	SchemaVersion string    `json:"schema_version"`
	EventType     string    `json:"event_type"`
	Source        string    `json:"source"`
	DeviceID      string    `json:"device_id"`
	SerialNumber  string    `json:"serial_number"`
	EventTS       time.Time `json:"event_ts"`
	ReceivedAt    time.Time `json:"received_at"`
	Status        string    `json:"status"`
}

func NewDeviceHeartbeatEvent(ev model.IngestEvent, receivedAt time.Time) (DeviceHeartbeatEvent, error) {
	sn := strings.TrimSpace(ev.SN)
	if sn == "" {
		return DeviceHeartbeatEvent{}, errors.New("heartbeat event requires serial number")
	}
	if ev.EventTS.IsZero() {
		return DeviceHeartbeatEvent{}, errors.New("heartbeat event requires event timestamp")
	}
	if receivedAt.IsZero() {
		receivedAt = time.Now().UTC()
	}

	source := strings.TrimSpace(ev.Source)
	if source == "" {
		source = "acs"
	}

	return DeviceHeartbeatEvent{
		SchemaVersion: DeviceHeartbeatSchemaVersion,
		EventType:     DeviceHeartbeatEventType,
		Source:        source,
		DeviceID:      sn,
		SerialNumber:  sn,
		EventTS:       ev.EventTS.UTC(),
		ReceivedAt:    receivedAt.UTC(),
		Status:        DeviceHeartbeatStatusOnline,
	}, nil
}

func (e DeviceHeartbeatEvent) Topic() string {
	return DeviceHeartbeatTopic
}

func (e DeviceHeartbeatEvent) Key() string {
	return e.DeviceID
}

