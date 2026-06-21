package events

import "context"

// PublishableEvent is the small contract that any outbound CPEmon event must
// satisfy before it can be sent through an EventPublisher.
type PublishableEvent interface {
	Topic() string
	Key() string
}

// EventPublisher is the application boundary used by ingest code. Concrete
// adapters, such as Kafka producers, implement this interface behind config.
type EventPublisher interface {
	Publish(ctx context.Context, event PublishableEvent) error
}

