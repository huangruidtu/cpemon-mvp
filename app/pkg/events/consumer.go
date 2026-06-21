package events

import (
	"context"
	"time"
)

// ConsumedEvent is the application-side envelope for one message read from an
// event stream. Kafka-specific adapters can populate partition and offset
// metadata while writer business logic depends only on this stable shape.
type ConsumedEvent struct {
	Topic     string
	Key       string
	Value     []byte
	Time      time.Time
	Partition int
	Offset    int64
}

// EventHandler processes one consumed event. Returning an error leaves the
// concrete consumer adapter responsible for retry, dead-letter, or offset
// commit behavior.
type EventHandler func(ctx context.Context, event ConsumedEvent) error

// EventConsumer is the application boundary used by cpemon-writer. Concrete
// adapters, such as Kafka consumers, implement this interface behind config.
type EventConsumer interface {
	Consume(ctx context.Context, handler EventHandler) error
	Close() error
}
