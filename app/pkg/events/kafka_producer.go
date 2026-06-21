package events

import (
	"context"
	"encoding/json"
	"errors"
	"fmt"
	"log"
	"strconv"
	"strings"
	"time"

	"github.com/prometheus/client_golang/prometheus"
	"github.com/segmentio/kafka-go"

	appconfig "github.com/huangruidtu/cpemon-mvp/app/pkg/config"
)

type kafkaMessageWriter interface {
	WriteMessages(ctx context.Context, msgs ...kafka.Message) error
	Close() error
}

var (
	kafkaProducerPublishesTotal = prometheus.NewCounterVec(
		prometheus.CounterOpts{
			Name: "acs_ingest_kafka_producer_publishes_total",
			Help: "Total number of Kafka publish attempts completed by acs-ingest.",
		},
		[]string{"topic", "result"},
	)

	kafkaProducerPublishErrorsTotal = prometheus.NewCounterVec(
		prometheus.CounterOpts{
			Name: "acs_ingest_kafka_producer_publish_errors_total",
			Help: "Total number of Kafka publish errors grouped by topic and error kind.",
		},
		[]string{"topic", "kind"},
	)

	kafkaProducerPublishDurationSeconds = prometheus.NewHistogramVec(
		prometheus.HistogramOpts{
			Name:    "acs_ingest_kafka_producer_publish_duration_seconds",
			Help:    "Kafka publish duration in seconds grouped by topic and result.",
			Buckets: prometheus.DefBuckets,
		},
		[]string{"topic", "result"},
	)
)

func KafkaProducerCollectors() []prometheus.Collector {
	return []prometheus.Collector{
		kafkaProducerPublishesTotal,
		kafkaProducerPublishErrorsTotal,
		kafkaProducerPublishDurationSeconds,
	}
}

// KafkaProducer publishes normalized CPEmon events to Kafka.
type KafkaProducer struct {
	writer     kafkaMessageWriter
	timeout    time.Duration
	maxRetries int
}

type KafkaProducerConfig struct {
	BootstrapServers string
	Timeout          time.Duration
	MaxRetries       int
}

type PublishErrorKind string

const (
	PublishErrorInvalidEvent       PublishErrorKind = "invalid_event"
	PublishErrorSerialization      PublishErrorKind = "serialization_error"
	PublishErrorTimeout            PublishErrorKind = "timeout"
	PublishErrorWriter             PublishErrorKind = "writer_error"
	DefaultKafkaProducerMaxRetries                  = 3
)

type KafkaPublishError struct {
	Kind     PublishErrorKind
	Topic    string
	Key      string
	Attempts int
	Err      error
}

func (e *KafkaPublishError) Error() string {
	if e == nil {
		return ""
	}
	message := "kafka publish failed kind=" + string(e.Kind)
	if e.Topic != "" {
		message += " topic=" + e.Topic
	}
	if e.Key != "" {
		message += " key=" + e.Key
	}
	if e.Attempts > 0 {
		message += " attempts=" + strconv.Itoa(e.Attempts)
	}
	if e.Err != nil {
		message += ": " + e.Err.Error()
	}
	return message
}

func (e *KafkaPublishError) Unwrap() error {
	if e == nil {
		return nil
	}
	return e.Err
}

func NewKafkaProducerFromConfig(cfg appconfig.Config) (*KafkaProducer, error) {
	return NewKafkaProducer(KafkaProducerConfig{
		BootstrapServers: cfg.KafkaBootstrapServers,
		Timeout:          cfg.KafkaProducerTimeout,
		MaxRetries:       cfg.KafkaProducerMaxRetries,
	})
}

func NewKafkaProducer(cfg KafkaProducerConfig) (*KafkaProducer, error) {
	brokers := parseBootstrapServers(cfg.BootstrapServers)
	if len(brokers) == 0 {
		return nil, errors.New("kafka producer requires at least one bootstrap server")
	}

	timeout := cfg.Timeout
	if timeout <= 0 {
		timeout = 5 * time.Second
	}

	return &KafkaProducer{
		writer: &kafka.Writer{
			Addr:         kafka.TCP(brokers...),
			Balancer:     &kafka.Hash{},
			RequiredAcks: kafka.RequireOne,
			Async:        false,
			BatchSize:    1,
		},
		timeout:    timeout,
		maxRetries: normalizeMaxRetries(cfg.MaxRetries),
	}, nil
}

func NewKafkaProducerWithWriter(writer kafkaMessageWriter, timeout time.Duration) (*KafkaProducer, error) {
	return NewKafkaProducerWithWriterAndRetry(writer, timeout, 0)
}

func NewKafkaProducerWithWriterAndRetry(writer kafkaMessageWriter, timeout time.Duration, maxRetries int) (*KafkaProducer, error) {
	if writer == nil {
		return nil, errors.New("kafka producer requires writer")
	}
	if timeout <= 0 {
		timeout = 5 * time.Second
	}
	return &KafkaProducer{
		writer:     writer,
		timeout:    timeout,
		maxRetries: normalizeMaxRetries(maxRetries),
	}, nil
}

func (p *KafkaProducer) Publish(ctx context.Context, event PublishableEvent) error {
	start := time.Now()
	if p == nil || p.writer == nil {
		return recordKafkaPublishFailure(start, newKafkaPublishError(PublishErrorInvalidEvent, "", "", 0, errors.New("kafka producer is not initialized")))
	}
	if event == nil {
		return recordKafkaPublishFailure(start, newKafkaPublishError(PublishErrorInvalidEvent, "", "", 0, errors.New("kafka producer requires event")))
	}

	topic := strings.TrimSpace(event.Topic())
	if topic == "" {
		return recordKafkaPublishFailure(start, newKafkaPublishError(PublishErrorInvalidEvent, "", "", 0, errors.New("kafka producer requires event topic")))
	}

	key := strings.TrimSpace(event.Key())
	if key == "" {
		return recordKafkaPublishFailure(start, newKafkaPublishError(PublishErrorInvalidEvent, topic, "", 0, errors.New("kafka producer requires event key")))
	}

	payload, err := json.Marshal(event)
	if err != nil {
		return recordKafkaPublishFailure(start, newKafkaPublishError(PublishErrorSerialization, topic, key, 0, fmt.Errorf("marshal kafka event: %w", err)))
	}

	attempts := p.maxRetries + 1
	var lastErr error
	for attempt := 1; attempt <= attempts; attempt++ {
		writeCtx := ctx
		cancel := func() {}
		if p.timeout > 0 {
			writeCtx, cancel = context.WithTimeout(ctx, p.timeout)
		}

		err = p.writer.WriteMessages(writeCtx, kafka.Message{
			Topic: topic,
			Key:   []byte(key),
			Value: payload,
			Time:  time.Now().UTC(),
		})
		cancel()
		if err == nil {
			recordKafkaPublishSuccess(start, topic, key, attempt)
			return nil
		}

		lastErr = err
		if ctx.Err() != nil {
			return recordKafkaPublishFailure(start, newKafkaPublishError(classifyKafkaPublishError(ctx.Err()), topic, key, attempt, ctx.Err()))
		}
	}

	return recordKafkaPublishFailure(start, newKafkaPublishError(classifyKafkaPublishError(lastErr), topic, key, attempts, lastErr))
}

func (p *KafkaProducer) Close() error {
	if p == nil || p.writer == nil {
		return nil
	}
	return p.writer.Close()
}

func parseBootstrapServers(value string) []string {
	parts := strings.Split(value, ",")
	brokers := make([]string, 0, len(parts))
	for _, part := range parts {
		if broker := strings.TrimSpace(part); broker != "" {
			brokers = append(brokers, broker)
		}
	}
	return brokers
}

func normalizeMaxRetries(maxRetries int) int {
	if maxRetries < 0 {
		return 0
	}
	return maxRetries
}

func newKafkaPublishError(kind PublishErrorKind, topic string, key string, attempts int, err error) error {
	return &KafkaPublishError{
		Kind:     kind,
		Topic:    topic,
		Key:      key,
		Attempts: attempts,
		Err:      err,
	}
}

func classifyKafkaPublishError(err error) PublishErrorKind {
	if errors.Is(err, context.DeadlineExceeded) || errors.Is(err, context.Canceled) {
		return PublishErrorTimeout
	}
	return PublishErrorWriter
}

func recordKafkaPublishSuccess(start time.Time, topic string, key string, attempts int) {
	duration := time.Since(start)
	kafkaProducerPublishesTotal.WithLabelValues(topic, "success").Inc()
	kafkaProducerPublishDurationSeconds.WithLabelValues(topic, "success").Observe(duration.Seconds())
	log.Printf("event=kafka_publish result=success topic=%s key=%s attempts=%d duration_ms=%d",
		topic, key, attempts, duration.Milliseconds())
}

func recordKafkaPublishFailure(start time.Time, err error) error {
	duration := time.Since(start)
	topic := "unknown"
	key := ""
	kind := PublishErrorWriter
	attempts := 0

	var publishErr *KafkaPublishError
	if errors.As(err, &publishErr) {
		if publishErr.Topic != "" {
			topic = publishErr.Topic
		}
		key = publishErr.Key
		kind = publishErr.Kind
		attempts = publishErr.Attempts
	}

	kafkaProducerPublishesTotal.WithLabelValues(topic, "error").Inc()
	kafkaProducerPublishErrorsTotal.WithLabelValues(topic, string(kind)).Inc()
	kafkaProducerPublishDurationSeconds.WithLabelValues(topic, "error").Observe(duration.Seconds())
	log.Printf("event=kafka_publish result=error topic=%s key=%s kind=%s attempts=%d duration_ms=%d error=%q",
		topic, key, kind, attempts, duration.Milliseconds(), err.Error())

	return err
}
