package events

import (
	"context"
	"errors"
	"testing"
	"time"
)

type recordingConsumer struct {
	events []ConsumedEvent
	closed bool
}

func (c *recordingConsumer) Consume(ctx context.Context, handler EventHandler) error {
	if err := ctx.Err(); err != nil {
		return err
	}
	for _, event := range c.events {
		if err := handler(ctx, event); err != nil {
			return err
		}
	}
	return nil
}

func (c *recordingConsumer) Close() error {
	c.closed = true
	return nil
}

func TestEventConsumerCanUseFakeWithoutKafka(t *testing.T) {
	eventTime := time.Date(2026, 6, 22, 8, 30, 0, 0, time.UTC)
	consumer := &recordingConsumer{
		events: []ConsumedEvent{
			{
				Topic:     DeviceHeartbeatTopic,
				Key:       "CPE-001",
				Value:     []byte(`{"event_type":"device.heartbeat"}`),
				Time:      eventTime,
				Partition: 2,
				Offset:    42,
			},
		},
	}
	var boundary EventConsumer = consumer

	var handled []ConsumedEvent
	err := boundary.Consume(context.Background(), func(ctx context.Context, event ConsumedEvent) error {
		if err := ctx.Err(); err != nil {
			return err
		}
		handled = append(handled, event)
		return nil
	})
	if err != nil {
		t.Fatalf("Consume returned error: %v", err)
	}

	if len(handled) != 1 {
		t.Fatalf("handled events = %d, want 1", len(handled))
	}
	if handled[0].Topic != DeviceHeartbeatTopic {
		t.Fatalf("topic = %q, want %q", handled[0].Topic, DeviceHeartbeatTopic)
	}
	if handled[0].Key != "CPE-001" {
		t.Fatalf("key = %q, want CPE-001", handled[0].Key)
	}
	if string(handled[0].Value) != `{"event_type":"device.heartbeat"}` {
		t.Fatalf("value = %q", string(handled[0].Value))
	}
	if handled[0].Partition != 2 || handled[0].Offset != 42 {
		t.Fatalf("metadata partition=%d offset=%d, want partition=2 offset=42", handled[0].Partition, handled[0].Offset)
	}
}

func TestEventConsumerPropagatesHandlerError(t *testing.T) {
	expected := errors.New("write failed")
	consumer := &recordingConsumer{
		events: []ConsumedEvent{{Topic: DeviceHeartbeatTopic, Key: "CPE-001"}},
	}

	err := consumer.Consume(context.Background(), func(ctx context.Context, event ConsumedEvent) error {
		return expected
	})
	if !errors.Is(err, expected) {
		t.Fatalf("Consume error = %v, want %v", err, expected)
	}
}

func TestEventConsumerPropagatesContextCancellation(t *testing.T) {
	ctx, cancel := context.WithCancel(context.Background())
	cancel()

	consumer := &recordingConsumer{}
	err := consumer.Consume(ctx, func(ctx context.Context, event ConsumedEvent) error {
		t.Fatal("handler should not run after context cancellation")
		return nil
	})
	if !errors.Is(err, context.Canceled) {
		t.Fatalf("Consume error = %v, want context.Canceled", err)
	}
}

func TestEventConsumerCloseLifecycle(t *testing.T) {
	consumer := &recordingConsumer{}
	var boundary EventConsumer = consumer

	if err := boundary.Close(); err != nil {
		t.Fatalf("Close returned error: %v", err)
	}
	if !consumer.closed {
		t.Fatal("consumer was not marked closed")
	}
}
