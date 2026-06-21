package events

import (
	"encoding/json"
	"errors"
	"strings"
	"time"

	"github.com/huangruidtu/cpemon-mvp/app/pkg/model"
)

const (
	WANStatusTopic         = "cpemon.wan.status.v1"
	WANStatusEventType     = "wan.status"
	WANStatusSchemaVersion = "v1"
	WANStatusUp            = "up"
)

// WANStatusEvent is the normalized Kafka event emitted by acs-ingest when WAN
// connectivity metadata is available in the ingest payload.
type WANStatusEvent struct {
	SchemaVersion  string    `json:"schema_version"`
	EventType      string    `json:"event_type"`
	Source         string    `json:"source"`
	DeviceID       string    `json:"device_id"`
	SerialNumber   string    `json:"serial_number"`
	EventTS        time.Time `json:"event_ts"`
	ReceivedAt     time.Time `json:"received_at"`
	WANStatus      string    `json:"wan_status"`
	WANIP          string    `json:"wan_ip,omitempty"`
	SoftwareVersion string  `json:"sw_version,omitempty"`
}

type rawWANStatusPayload struct {
	WANIP           string `json:"wan_ip"`
	WANStatus      string `json:"wan_status"`
	WANState       string `json:"wan_state"`
	Status         string `json:"status"`
	SoftwareVersion string `json:"sw_version"`
}

func NewWANStatusEvent(ev model.IngestEvent, receivedAt time.Time) (WANStatusEvent, error) {
	sn := strings.TrimSpace(ev.SN)
	if sn == "" {
		return WANStatusEvent{}, errors.New("wan status event requires serial number")
	}
	if ev.EventTS.IsZero() {
		return WANStatusEvent{}, errors.New("wan status event requires event timestamp")
	}

	var payload rawWANStatusPayload
	if len(ev.Payload) > 0 {
		if err := json.Unmarshal(ev.Payload, &payload); err != nil {
			return WANStatusEvent{}, errors.New("wan status event payload must be valid JSON")
		}
	}

	wanIP := strings.TrimSpace(payload.WANIP)
	wanStatus := firstNonEmpty(payload.WANStatus, payload.WANState, payload.Status)
	if wanStatus == "" && wanIP != "" {
		wanStatus = WANStatusUp
	}
	if wanStatus == "" {
		return WANStatusEvent{}, errors.New("wan status event requires wan_status, wan_state, status, or wan_ip")
	}

	if receivedAt.IsZero() {
		receivedAt = time.Now().UTC()
	}

	source := strings.TrimSpace(ev.Source)
	if source == "" {
		source = "acs"
	}

	return WANStatusEvent{
		SchemaVersion:  WANStatusSchemaVersion,
		EventType:      WANStatusEventType,
		Source:         source,
		DeviceID:       sn,
		SerialNumber:   sn,
		EventTS:        ev.EventTS.UTC(),
		ReceivedAt:     receivedAt.UTC(),
		WANStatus:      wanStatus,
		WANIP:          wanIP,
		SoftwareVersion: strings.TrimSpace(payload.SoftwareVersion),
	}, nil
}

func (e WANStatusEvent) Topic() string {
	return WANStatusTopic
}

func (e WANStatusEvent) Key() string {
	return e.DeviceID
}

func firstNonEmpty(values ...string) string {
	for _, value := range values {
		if trimmed := strings.TrimSpace(value); trimmed != "" {
			return trimmed
		}
	}
	return ""
}

