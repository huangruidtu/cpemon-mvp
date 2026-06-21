package main

import (
	"context"
	"errors"
	"fmt"
	"log"
	"strconv"
	"strings"
	"time"

	"github.com/prometheus/client_golang/prometheus"

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

var (
	writerKafkaProcessingEventsTotal = prometheus.NewCounterVec(
		prometheus.CounterOpts{
			Name: "cpemon_writer_kafka_processing_events_total",
			Help: "Total cpemon-writer Kafka processing outcomes grouped by topic, result, and failure kind.",
		},
		[]string{"topic", "result", "kind"},
	)

	writerKafkaProcessingRetriesTotal = prometheus.NewCounterVec(
		prometheus.CounterOpts{
			Name: "cpemon_writer_kafka_processing_retries_total",
			Help: "Total cpemon-writer Kafka processing retries grouped by topic and failure kind.",
		},
		[]string{"topic", "kind"},
	)

	writerKafkaDeadLettersTotal = prometheus.NewCounterVec(
		prometheus.CounterOpts{
			Name: "cpemon_writer_kafka_deadletters_total",
			Help: "Total cpemon-writer Kafka dead-letter publish outcomes grouped by source topic, result, and failure kind.",
		},
		[]string{"topic", "result", "kind"},
	)

	writerKafkaProcessingDurationSeconds = prometheus.NewHistogramVec(
		prometheus.HistogramOpts{
			Name:    "cpemon_writer_kafka_processing_duration_seconds",
			Help:    "cpemon-writer Kafka processing duration in seconds grouped by topic, result, and failure kind.",
			Buckets: prometheus.DefBuckets,
		},
		[]string{"topic", "result", "kind"},
	)
)

func writerKafkaProcessingCollectors() []prometheus.Collector {
	return []prometheus.Collector{
		writerKafkaProcessingEventsTotal,
		writerKafkaProcessingRetriesTotal,
		writerKafkaDeadLettersTotal,
		writerKafkaProcessingDurationSeconds,
	}
}

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
	start := opts.Now()
	attempts := opts.MaxRetries + 1
	var lastErr error

	for attempt := 1; attempt <= attempts; attempt++ {
		if err := ctx.Err(); err != nil {
			recordKafkaProcessingError(start, event, "context_canceled", attempt, err)
			return err
		}

		err := processConsumedEvent(ctx, exec, event)
		if err == nil {
			recordKafkaProcessingSuccess(start, event, attempt)
			return nil
		}
		lastErr = err

		if err := ctx.Err(); err != nil {
			recordKafkaProcessingError(start, event, "context_canceled", attempt, err)
			return err
		}

		failureKind := classifyConsumerFailure(err)
		if failureKind == consumerFailurePoison {
			return publishDeadLetter(ctx, publisher, event, opts, start, attempt, failureKind, err)
		}
		if attempt == attempts {
			return publishDeadLetter(ctx, publisher, event, opts, start, attempt, failureKind, err)
		}
		recordKafkaProcessingRetry(start, event, attempt, failureKind, err, opts.RetryBackoff)
		if err := opts.Sleep(ctx, opts.RetryBackoff); err != nil {
			recordKafkaProcessingError(start, event, "retry_sleep_error", attempt, err)
			return err
		}
	}

	return lastErr
}

func publishDeadLetter(ctx context.Context, publisher events.EventPublisher, event events.ConsumedEvent, opts consumerRetryOptions, start time.Time, attempts int, kind consumerFailureKind, cause error) error {
	if publisher == nil {
		err := fmt.Errorf("dead-letter publisher is required for %s after %d attempts: %w", kind, attempts, cause)
		recordKafkaDeadLetterFailure(start, event, attempts, kind, err)
		return err
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
		wrapped := fmt.Errorf("publish dead-letter event: %w", err)
		recordKafkaDeadLetterFailure(start, event, attempts, kind, wrapped)
		return wrapped
	}
	recordKafkaDeadLetterSuccess(start, event, attempts, kind, cause)
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

func recordKafkaProcessingSuccess(start time.Time, event events.ConsumedEvent, attempts int) {
	topic := metricTopic(event.Topic)
	duration := time.Since(start)
	writerKafkaProcessingEventsTotal.WithLabelValues(topic, "success", "none").Inc()
	writerKafkaProcessingDurationSeconds.WithLabelValues(topic, "success", "none").Observe(duration.Seconds())
	log.Printf("event=writer_kafka_process result=success topic=%s key=%s partition=%d offset=%d attempts=%d duration_ms=%d",
		event.Topic, event.Key, event.Partition, event.Offset, attempts, duration.Milliseconds())
}

func recordKafkaProcessingRetry(start time.Time, event events.ConsumedEvent, attempt int, kind consumerFailureKind, cause error, backoff time.Duration) {
	topic := metricTopic(event.Topic)
	writerKafkaProcessingEventsTotal.WithLabelValues(topic, "retry", string(kind)).Inc()
	writerKafkaProcessingRetriesTotal.WithLabelValues(topic, string(kind)).Inc()
	log.Printf("event=writer_kafka_process result=retry topic=%s key=%s partition=%d offset=%d attempt=%d kind=%s backoff_ms=%d duration_ms=%d error=%q",
		event.Topic, event.Key, event.Partition, event.Offset, attempt, kind, backoff.Milliseconds(), time.Since(start).Milliseconds(), cause.Error())
}

func recordKafkaProcessingError(start time.Time, event events.ConsumedEvent, kind string, attempts int, cause error) {
	topic := metricTopic(event.Topic)
	duration := time.Since(start)
	writerKafkaProcessingEventsTotal.WithLabelValues(topic, "error", kind).Inc()
	writerKafkaProcessingDurationSeconds.WithLabelValues(topic, "error", kind).Observe(duration.Seconds())
	log.Printf("event=writer_kafka_process result=error topic=%s key=%s partition=%d offset=%d attempts=%d kind=%s duration_ms=%d error=%q",
		event.Topic, event.Key, event.Partition, event.Offset, attempts, kind, duration.Milliseconds(), cause.Error())
}

func recordKafkaDeadLetterSuccess(start time.Time, event events.ConsumedEvent, attempts int, kind consumerFailureKind, cause error) {
	topic := metricTopic(event.Topic)
	duration := time.Since(start)
	writerKafkaProcessingEventsTotal.WithLabelValues(topic, "dead_letter", string(kind)).Inc()
	writerKafkaDeadLettersTotal.WithLabelValues(topic, "success", string(kind)).Inc()
	writerKafkaProcessingDurationSeconds.WithLabelValues(topic, "dead_letter", string(kind)).Observe(duration.Seconds())
	log.Printf("event=writer_kafka_deadletter result=success source_topic=%s key=%s partition=%d offset=%d attempts=%d kind=%s duration_ms=%d reason=%q",
		event.Topic, event.Key, event.Partition, event.Offset, attempts, kind, duration.Milliseconds(), cause.Error())
}

func recordKafkaDeadLetterFailure(start time.Time, event events.ConsumedEvent, attempts int, kind consumerFailureKind, cause error) {
	topic := metricTopic(event.Topic)
	duration := time.Since(start)
	writerKafkaProcessingEventsTotal.WithLabelValues(topic, "error", "dead_letter_publish_error").Inc()
	writerKafkaDeadLettersTotal.WithLabelValues(topic, "error", string(kind)).Inc()
	writerKafkaProcessingDurationSeconds.WithLabelValues(topic, "error", "dead_letter_publish_error").Observe(duration.Seconds())
	log.Printf("event=writer_kafka_deadletter result=error source_topic=%s key=%s partition=%d offset=%d attempts=%d kind=%s duration_ms=%d error=%q",
		event.Topic, event.Key, event.Partition, event.Offset, attempts, kind, duration.Milliseconds(), cause.Error())
}

func metricTopic(topic string) string {
	trimmed := strings.TrimSpace(topic)
	if trimmed == "" {
		return "unknown"
	}
	return trimmed
}
