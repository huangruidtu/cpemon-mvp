package main

import (
	"context"
	"errors"
	"testing"
	"time"

	"github.com/huangruidtu/cpemon-mvp/app/pkg/events"
	"github.com/huangruidtu/cpemon-mvp/app/pkg/model"
	"github.com/prometheus/client_golang/prometheus"
)

type fakeEventPublisher struct {
	events []events.PublishableEvent
	err    error
}

func (p *fakeEventPublisher) Publish(ctx context.Context, event events.PublishableEvent) error {
	if p.err != nil {
		return p.err
	}
	p.events = append(p.events, event)
	return nil
}

func TestPublishACSKafkaEventsNoopsWhenPublisherDisabled(t *testing.T) {
	err := publishACSKafkaEvents(context.Background(), nil, validIngestEvent([]byte(`{"wan_status":"up"}`)), time.Now())
	if err != nil {
		t.Fatalf("publishACSKafkaEvents returned error: %v", err)
	}
}

func TestPublishACSKafkaEventsPublishesHeartbeatAndWANStatus(t *testing.T) {
	publisher := &fakeEventPublisher{}
	receivedAt := time.Date(2026, 6, 21, 10, 31, 0, 0, time.UTC)

	err := publishACSKafkaEvents(
		context.Background(),
		publisher,
		validIngestEvent([]byte(`{"wan_ip":"10.0.0.13","wan_status":"up"}`)),
		receivedAt,
	)
	if err != nil {
		t.Fatalf("publishACSKafkaEvents returned error: %v", err)
	}

	if len(publisher.events) != 2 {
		t.Fatalf("published events = %d, want 2", len(publisher.events))
	}
	if publisher.events[0].Topic() != events.DeviceHeartbeatTopic {
		t.Fatalf("first topic = %q, want %q", publisher.events[0].Topic(), events.DeviceHeartbeatTopic)
	}
	if publisher.events[1].Topic() != events.WANStatusTopic {
		t.Fatalf("second topic = %q, want %q", publisher.events[1].Topic(), events.WANStatusTopic)
	}
	for _, event := range publisher.events {
		if event.Key() != "CPE-001" {
			t.Fatalf("event key = %q, want CPE-001", event.Key())
		}
	}
}

func TestPublishACSKafkaEventsSkipsWANStatusWhenPayloadHasNoWANData(t *testing.T) {
	publisher := &fakeEventPublisher{}

	err := publishACSKafkaEvents(
		context.Background(),
		publisher,
		validIngestEvent([]byte(`{"sw_version":"v1.0-demo"}`)),
		time.Now(),
	)
	if err != nil {
		t.Fatalf("publishACSKafkaEvents returned error: %v", err)
	}

	if len(publisher.events) != 1 {
		t.Fatalf("published events = %d, want 1", len(publisher.events))
	}
	if publisher.events[0].Topic() != events.DeviceHeartbeatTopic {
		t.Fatalf("topic = %q, want %q", publisher.events[0].Topic(), events.DeviceHeartbeatTopic)
	}
}

func TestPublishACSKafkaEventsReturnsWANBuildError(t *testing.T) {
	publisher := &fakeEventPublisher{}

	err := publishACSKafkaEvents(
		context.Background(),
		publisher,
		validIngestEvent([]byte(`not-json`)),
		time.Now(),
	)
	if err == nil {
		t.Fatal("expected WAN status build error")
	}
	if len(publisher.events) != 1 {
		t.Fatalf("published events = %d, want heartbeat before WAN build failure", len(publisher.events))
	}
	if publisher.events[0].Topic() != events.DeviceHeartbeatTopic {
		t.Fatalf("topic = %q, want %q", publisher.events[0].Topic(), events.DeviceHeartbeatTopic)
	}
}

func TestPublishACSKafkaEventsReturnsPublishError(t *testing.T) {
	wantErr := errors.New("write failed")
	publisher := &fakeEventPublisher{err: wantErr}

	err := publishACSKafkaEvents(
		context.Background(),
		publisher,
		validIngestEvent([]byte(`{"wan_status":"up"}`)),
		time.Now(),
	)
	if err == nil {
		t.Fatal("expected publish error")
	}
	if !errors.Is(err, wantErr) {
		t.Fatalf("error = %v, want wrapped publish error", err)
	}
}

func TestACSIngestCollectorsAreExposed(t *testing.T) {
	registry := prometheus.NewRegistry()
	for _, collector := range acsIngestCollectors() {
		if err := registry.Register(collector); err != nil {
			t.Fatalf("register collector: %v", err)
		}
	}

	webhookRequestsTotal.WithLabelValues("202").Inc()
	webhookErrorsTotal.WithLabelValues("invalid_json").Inc()
	webhookDurationSeconds.WithLabelValues("202").Observe(0.01)
	webhookPayloadBytes.Observe(512)
	acsIngestEventsTotal.WithLabelValues("queued").Inc()

	metrics, err := registry.Gather()
	if err != nil {
		t.Fatalf("gather metrics: %v", err)
	}

	got := map[string]bool{}
	for _, metric := range metrics {
		got[metric.GetName()] = true
	}

	for _, want := range []string{
		"acs_webhook_requests_total",
		"acs_webhook_errors_total",
		"acs_webhook_duration_seconds",
		"acs_webhook_payload_bytes",
		"acs_ingest_events_total",
	} {
		if !got[want] {
			t.Fatalf("metric %q was not gathered", want)
		}
	}
}

func validIngestEvent(payload []byte) model.IngestEvent {
	return model.IngestEvent{
		Source:  "acs",
		SN:      "CPE-001",
		EventTS: time.Date(2026, 6, 21, 10, 30, 0, 0, time.UTC),
		Payload: payload,
	}
}
