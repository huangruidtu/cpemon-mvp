package events

import (
	"context"
	"testing"
	"time"

	"github.com/huangruidtu/cpemon-mvp/app/pkg/model"
)

type recordingPublisher struct {
	events []PublishableEvent
}

func (p *recordingPublisher) Publish(ctx context.Context, event PublishableEvent) error {
	if err := ctx.Err(); err != nil {
		return err
	}
	p.events = append(p.events, event)
	return nil
}

func TestHeartbeatAndWANStatusEventsArePublishable(t *testing.T) {
	eventTS := time.Date(2026, 6, 21, 10, 30, 0, 0, time.UTC)
	receivedAt := time.Date(2026, 6, 21, 10, 31, 0, 0, time.UTC)

	heartbeat, err := NewDeviceHeartbeatEvent(model.IngestEvent{
		Source:  "acs",
		SN:      "CPE-001",
		EventTS: eventTS,
	}, receivedAt)
	if err != nil {
		t.Fatalf("NewDeviceHeartbeatEvent returned error: %v", err)
	}

	wan, err := NewWANStatusEvent(model.IngestEvent{
		Source:  "acs",
		SN:      "CPE-001",
		EventTS: eventTS,
		Payload: []byte(`{"wan_ip":"10.0.0.13"}`),
	}, receivedAt)
	if err != nil {
		t.Fatalf("NewWANStatusEvent returned error: %v", err)
	}

	var _ PublishableEvent = heartbeat
	var _ PublishableEvent = wan
}

func TestEventPublisherCanUseFakeWithoutKafka(t *testing.T) {
	eventTS := time.Date(2026, 6, 21, 10, 30, 0, 0, time.UTC)
	receivedAt := time.Date(2026, 6, 21, 10, 31, 0, 0, time.UTC)

	heartbeat, err := NewDeviceHeartbeatEvent(model.IngestEvent{
		Source:  "acs",
		SN:      "CPE-001",
		EventTS: eventTS,
	}, receivedAt)
	if err != nil {
		t.Fatalf("NewDeviceHeartbeatEvent returned error: %v", err)
	}

	publisher := &recordingPublisher{}
	var boundary EventPublisher = publisher

	if err := boundary.Publish(context.Background(), heartbeat); err != nil {
		t.Fatalf("Publish returned error: %v", err)
	}

	if len(publisher.events) != 1 {
		t.Fatalf("recorded events = %d, want 1", len(publisher.events))
	}
	if publisher.events[0].Topic() != DeviceHeartbeatTopic {
		t.Fatalf("recorded topic = %q, want %q", publisher.events[0].Topic(), DeviceHeartbeatTopic)
	}
	if publisher.events[0].Key() != "CPE-001" {
		t.Fatalf("recorded key = %q, want CPE-001", publisher.events[0].Key())
	}
}

func TestEventPublisherPropagatesContextCancellation(t *testing.T) {
	ctx, cancel := context.WithCancel(context.Background())
	cancel()

	publisher := &recordingPublisher{}
	event := DeviceHeartbeatEvent{
		DeviceID: "CPE-001",
	}

	if err := publisher.Publish(ctx, event); err == nil {
		t.Fatal("expected cancellation error")
	}
}

