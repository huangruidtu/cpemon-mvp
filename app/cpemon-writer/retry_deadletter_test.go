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

type flakyExec struct {
	failures int
	err      error
	calls    int
}

func (e *flakyExec) ExecContext(ctx context.Context, query string, args ...any) (sql.Result, error) {
	if err := ctx.Err(); err != nil {
		return nil, err
	}
	e.calls++
	if e.failures > 0 {
		e.failures--
		return nil, e.err
	}
	return fakeSQLResult(1), nil
}

type recordedPublisher struct {
	events []events.PublishableEvent
	err    error
}

func (p *recordedPublisher) Publish(ctx context.Context, event events.PublishableEvent) error {
	if err := ctx.Err(); err != nil {
		return err
	}
	if p.err != nil {
		return p.err
	}
	p.events = append(p.events, event)
	return nil
}

func TestWriterKafkaProcessingCollectorsAreExposed(t *testing.T) {
	collectors := writerKafkaProcessingCollectors()
	if len(collectors) != 4 {
		t.Fatalf("collectors = %d, want 4", len(collectors))
	}
}

func TestProcessConsumedEventWithReliabilityRetriesRetriableError(t *testing.T) {
	dbErr := errors.New("db unavailable")
	exec := &flakyExec{failures: 1, err: dbErr}
	publisher := &recordedPublisher{}
	event := validHeartbeatConsumedEvent()
	var sleeps []time.Duration

	err := processConsumedEventWithReliability(context.Background(), exec, publisher, event, consumerRetryOptions{
		MaxRetries:      2,
		RetryBackoff:    25 * time.Millisecond,
		DeadLetterTopic: "cpemon.deadletter.v1",
		Sleep: func(ctx context.Context, delay time.Duration) error {
			sleeps = append(sleeps, delay)
			return nil
		},
	})
	if err != nil {
		t.Fatalf("processConsumedEventWithReliability returned error: %v", err)
	}
	if exec.calls != 3 {
		t.Fatalf("exec calls = %d, want 3 across failed first attempt and successful retry", exec.calls)
	}
	if len(sleeps) != 1 || sleeps[0] != 25*time.Millisecond {
		t.Fatalf("sleeps = %#v, want one 25ms backoff", sleeps)
	}
	if len(publisher.events) != 0 {
		t.Fatalf("dead-letter events = %d, want 0 after successful retry", len(publisher.events))
	}
}

func TestProcessConsumedEventWithReliabilityPublishesPoisonMessageToDeadLetter(t *testing.T) {
	publisher := &recordedPublisher{}
	failedAt := time.Date(2026, 6, 22, 12, 30, 0, 0, time.UTC)

	err := processConsumedEventWithReliability(context.Background(), &recordedExec{}, publisher, events.ConsumedEvent{
		Topic:     events.DeviceHeartbeatTopic,
		Key:       "CPE-001",
		Value:     []byte(`not-json`),
		Partition: 2,
		Offset:    42,
	}, consumerRetryOptions{
		MaxRetries:      3,
		DeadLetterTopic: "cpemon.deadletter.v1",
		Now: func() time.Time {
			return failedAt
		},
		Sleep: func(ctx context.Context, delay time.Duration) error {
			t.Fatal("poison message should not be retried")
			return nil
		},
	})
	if err != nil {
		t.Fatalf("processConsumedEventWithReliability returned error: %v", err)
	}
	if len(publisher.events) != 1 {
		t.Fatalf("dead-letter events = %d, want 1", len(publisher.events))
	}
	deadLetter, ok := publisher.events[0].(deadLetterEvent)
	if !ok {
		t.Fatalf("dead-letter event type = %T, want deadLetterEvent", publisher.events[0])
	}
	if deadLetter.Topic() != "cpemon.deadletter.v1" {
		t.Fatalf("dead-letter topic = %q", deadLetter.Topic())
	}
	if deadLetter.Key() != "CPE-001" {
		t.Fatalf("dead-letter key = %q", deadLetter.Key())
	}
	if deadLetter.FailureKind != string(consumerFailurePoison) {
		t.Fatalf("failure kind = %q, want poison", deadLetter.FailureKind)
	}
	if deadLetter.Attempts != 1 {
		t.Fatalf("attempts = %d, want 1 for poison message", deadLetter.Attempts)
	}
	if !strings.Contains(deadLetter.Reason, "decode heartbeat payload") {
		t.Fatalf("reason = %q", deadLetter.Reason)
	}
	if !deadLetter.FailedAt.Equal(failedAt) {
		t.Fatalf("failed_at = %s, want %s", deadLetter.FailedAt, failedAt)
	}
}

func TestProcessConsumedEventWithReliabilityPublishesRetriableFailureAfterLimit(t *testing.T) {
	dbErr := errors.New("db unavailable")
	exec := &flakyExec{failures: 10, err: dbErr}
	publisher := &recordedPublisher{}

	err := processConsumedEventWithReliability(context.Background(), exec, publisher, validHeartbeatConsumedEvent(), consumerRetryOptions{
		MaxRetries:      2,
		DeadLetterTopic: "cpemon.deadletter.v1",
		Sleep: func(ctx context.Context, delay time.Duration) error {
			return nil
		},
	})
	if err != nil {
		t.Fatalf("processConsumedEventWithReliability returned error: %v", err)
	}
	if exec.calls != 3 {
		t.Fatalf("exec calls = %d, want 3 total attempts", exec.calls)
	}
	if len(publisher.events) != 1 {
		t.Fatalf("dead-letter events = %d, want 1", len(publisher.events))
	}
	deadLetter := publisher.events[0].(deadLetterEvent)
	if deadLetter.FailureKind != string(consumerFailureRetriable) {
		t.Fatalf("failure kind = %q, want retriable", deadLetter.FailureKind)
	}
	if deadLetter.Attempts != 3 {
		t.Fatalf("attempts = %d, want 3", deadLetter.Attempts)
	}
	if !strings.Contains(deadLetter.Reason, dbErr.Error()) {
		t.Fatalf("reason = %q", deadLetter.Reason)
	}
}

func TestProcessConsumedEventWithReliabilityReturnsDeadLetterPublishError(t *testing.T) {
	publishErr := errors.New("dead-letter broker unavailable")
	publisher := &recordedPublisher{err: publishErr}

	err := processConsumedEventWithReliability(context.Background(), &recordedExec{}, publisher, events.ConsumedEvent{
		Topic: events.DeviceHeartbeatTopic,
		Key:   "CPE-001",
		Value: []byte(`not-json`),
	}, consumerRetryOptions{})
	if !errors.Is(err, publishErr) {
		t.Fatalf("error = %v, want wrapped publish error", err)
	}
	if !strings.Contains(err.Error(), "publish dead-letter event") {
		t.Fatalf("error = %q, want dead-letter context", err.Error())
	}
}

func validHeartbeatConsumedEvent() events.ConsumedEvent {
	return events.ConsumedEvent{
		Topic:     events.DeviceHeartbeatTopic,
		Key:       "CPE-001",
		Value:     []byte(`{"schema_version":"v1","event_type":"device.heartbeat","device_id":"CPE-001","event_ts":"2026-06-22T10:00:00Z","status":"online"}`),
		Partition: 1,
		Offset:    10,
	}
}
