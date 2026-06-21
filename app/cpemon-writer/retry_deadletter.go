package main

import (
	"context"
	"errors"
	"fmt"
	"strconv"
	"strings"
	"time"

	"github.com/huangruidtu/cpemon-mvp/app/pkg/events"
)

const (
	deadLetterSchemaVersion = "v1"
	deadLetterEventType     = "consumer.deadletter"
)

type consumerFailureKind string

const (
	consumerFailureRetriable consumerFailureKind = "retriable_error"
	consumerFailurePoison    consumerFailureKind = "poison_message"
)

type consumerRetryOptions struct {
	MaxRetries      int
	RetryBackoff    time.Duration
	DeadLetterTopic string
	Now             func() time.Time
	Sleep           func(context.Context, time.Duration) error
}

type deadLetterEvent struct {
	SchemaVersion string    `json:"schema_version"`
	EventType     string    `json:"event_type"`
	SourceTopic   string    `json:"source_topic"`
	SourceKey     string    `json:"source_key,omitempty"`
	Partition     int       `json:"partition"`
	Offset        int64     `json:"offset"`
	FailureKind   string    `json:"failure_kind"`
	Reason        string    `json:"reason"`
	Attempts      int       `json:"attempts"`
	FailedAt      time.Time `json:"failed_at"`
	Payload       string    `json:"payload,omitempty"`

	topic string
	key   string
}

func (e deadLetterEvent) Topic() string {
	return e.topic
}

func (e deadLetterEvent) Key() string {
	if strings.TrimSpace(e.key) != "" {
		return e.key
	}
	return e.SourceTopic + ":" + strconv.Itoa(e.Partition) + ":" + strconv.FormatInt(e.Offset, 10)
}

func processConsumedEventWithReliability(ctx context.Context, exec sqlExecutor, publisher events.EventPublisher, event events.ConsumedEvent, opts consumerRetryOptions) error {
	opts = normalizeConsumerRetryOptions(opts)
	attempts := opts.MaxRetries + 1
	var lastErr error

	for attempt := 1; attempt <= attempts; attempt++ {
		if err := ctx.Err(); err != nil {
			return err
		}

		err := processConsumedEvent(ctx, exec, event)
		if err == nil {
			return nil
		}
		lastErr = err

		if err := ctx.Err(); err != nil {
			return err
		}

		failureKind := classifyConsumerFailure(err)
		if failureKind == consumerFailurePoison {
			return publishDeadLetter(ctx, publisher, event, opts, attempt, failureKind, err)
		}
		if attempt == attempts {
			return publishDeadLetter(ctx, publisher, event, opts, attempt, failureKind, err)
		}
		if err := opts.Sleep(ctx, opts.RetryBackoff); err != nil {
			return err
		}
	}

	return lastErr
}

func publishDeadLetter(ctx context.Context, publisher events.EventPublisher, event events.ConsumedEvent, opts consumerRetryOptions, attempts int, kind consumerFailureKind, cause error) error {
	if publisher == nil {
		return fmt.Errorf("dead-letter publisher is required for %s after %d attempts: %w", kind, attempts, cause)
	}
	deadLetter := deadLetterEvent{
		SchemaVersion: deadLetterSchemaVersion,
		EventType:     deadLetterEventType,
		SourceTopic:   event.Topic,
		SourceKey:     event.Key,
		Partition:     event.Partition,
		Offset:        event.Offset,
		FailureKind:   string(kind),
		Reason:        cause.Error(),
		Attempts:      attempts,
		FailedAt:      opts.Now().UTC(),
		Payload:       string(event.Value),
		topic:         opts.DeadLetterTopic,
		key:           event.Key,
	}
	if err := publisher.Publish(ctx, deadLetter); err != nil {
		return fmt.Errorf("publish dead-letter event: %w", err)
	}
	return nil
}

func classifyConsumerFailure(err error) consumerFailureKind {
	if err == nil {
		return consumerFailureRetriable
	}
	if errors.Is(err, context.Canceled) || errors.Is(err, context.DeadlineExceeded) {
		return consumerFailureRetriable
	}

	text := strings.ToLower(err.Error())
	poisonTokens := []string{
		"unsupported consumed event topic",
		"payload is empty",
		"decode ",
		"schema_version",
		"event_type",
		"device identity",
		"does not match",
		" is required",
		"unexpected topic",
	}
	for _, token := range poisonTokens {
		if strings.Contains(text, token) {
			return consumerFailurePoison
		}
	}
	return consumerFailureRetriable
}

func normalizeConsumerRetryOptions(opts consumerRetryOptions) consumerRetryOptions {
	if opts.MaxRetries < 0 {
		opts.MaxRetries = 0
	}
	if opts.RetryBackoff < 0 {
		opts.RetryBackoff = 0
	}
	if strings.TrimSpace(opts.DeadLetterTopic) == "" {
		opts.DeadLetterTopic = "cpemon.deadletter.v1"
	}
	if opts.Now == nil {
		opts.Now = time.Now
	}
	if opts.Sleep == nil {
		opts.Sleep = sleepWithContext
	}
	return opts
}

func sleepWithContext(ctx context.Context, delay time.Duration) error {
	if delay <= 0 {
		return nil
	}
	timer := time.NewTimer(delay)
	defer timer.Stop()

	select {
	case <-ctx.Done():
		return ctx.Err()
	case <-timer.C:
		return nil
	}
}
