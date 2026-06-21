package events

import (
	"context"
	"errors"
	"fmt"
	"strconv"
	"strings"
	"time"

	"github.com/prometheus/client_golang/prometheus"
	"github.com/segmentio/kafka-go"

	appconfig "github.com/huangruidtu/cpemon-mvp/app/pkg/config"
)

type kafkaMessageReader interface {
	FetchMessage(ctx context.Context) (kafka.Message, error)
	CommitMessages(ctx context.Context, msgs ...kafka.Message) error
	Stats() kafka.ReaderStats
	Close() error
}

var (
	kafkaConsumerLastConsumedOffset = prometheus.NewGaugeVec(
		prometheus.GaugeOpts{
			Name: "cpemon_writer_kafka_consumer_last_consumed_offset",
			Help: "Last Kafka offset consumed by cpemon-writer, labeled by consumer group, topic, and partition.",
		},
		[]string{"group", "topic", "partition"},
	)

	kafkaConsumerLastCommittedOffset = prometheus.NewGaugeVec(
		prometheus.GaugeOpts{
			Name: "cpemon_writer_kafka_consumer_last_committed_offset",
			Help: "Last Kafka offset committed by cpemon-writer after successful processing, labeled by consumer group, topic, and partition.",
		},
		[]string{"group", "topic", "partition"},
	)

	kafkaConsumerMessageAgeSeconds = prometheus.NewGaugeVec(
		prometheus.GaugeOpts{
			Name: "cpemon_writer_kafka_consumer_message_age_seconds",
			Help: "Age in seconds of the last Kafka message consumed by cpemon-writer, labeled by consumer group, topic, and partition.",
		},
		[]string{"group", "topic", "partition"},
	)

	kafkaConsumerReaderLagMessages = prometheus.NewGaugeVec(
		prometheus.GaugeOpts{
			Name: "cpemon_writer_kafka_consumer_reader_lag_messages",
			Help: "Reader-reported Kafka lag when available. In consumer group mode kafka-go may report -1, so absence of this sample should be paired with broker-side lag metrics.",
		},
		[]string{"group", "topic", "partition"},
	)
)

func KafkaConsumerCollectors() []prometheus.Collector {
	return []prometheus.Collector{
		kafkaConsumerLastConsumedOffset,
		kafkaConsumerLastCommittedOffset,
		kafkaConsumerMessageAgeSeconds,
		kafkaConsumerReaderLagMessages,
	}
}

// KafkaConsumer consumes normalized CPEmon events from Kafka and exposes them
// through the EventConsumer application boundary.
type KafkaConsumer struct {
	reader        kafkaMessageReader
	groupID       string
	commitTimeout time.Duration
}

type KafkaConsumerConfig struct {
	BootstrapServers string
	GroupID          string
	Topics           []string
	ReadTimeout      time.Duration
	CommitTimeout    time.Duration
}

type ConsumeErrorKind string

const (
	ConsumeErrorInvalidConfig ConsumeErrorKind = "invalid_config"
	ConsumeErrorFetch         ConsumeErrorKind = "fetch_error"
	ConsumeErrorHandler       ConsumeErrorKind = "handler_error"
	ConsumeErrorCommit        ConsumeErrorKind = "commit_error"
)

type KafkaConsumeError struct {
	Kind      ConsumeErrorKind
	Topic     string
	Key       string
	Partition int
	Offset    int64
	Err       error
}

func (e *KafkaConsumeError) Error() string {
	if e == nil {
		return ""
	}
	message := "kafka consume failed kind=" + string(e.Kind)
	if e.Topic != "" {
		message += " topic=" + e.Topic
	}
	if e.Key != "" {
		message += " key=" + e.Key
	}
	if e.Partition != 0 {
		message += " partition=" + strconv.Itoa(e.Partition)
	}
	if e.Offset != 0 {
		message += " offset=" + strconv.FormatInt(e.Offset, 10)
	}
	if e.Err != nil {
		message += ": " + e.Err.Error()
	}
	return message
}

func (e *KafkaConsumeError) Unwrap() error {
	if e == nil {
		return nil
	}
	return e.Err
}

func NewKafkaConsumerFromConfig(cfg appconfig.Config) (*KafkaConsumer, error) {
	return NewKafkaConsumer(KafkaConsumerConfig{
		BootstrapServers: cfg.KafkaBootstrapServers,
		GroupID:          cfg.KafkaConsumerGroupID,
		Topics:           KafkaConsumerTopicsFromConfig(cfg),
		ReadTimeout:      cfg.KafkaConsumerReadTimeout,
		CommitTimeout:    cfg.KafkaConsumerCommitTimeout,
	})
}

func KafkaConsumerTopicsFromConfig(cfg appconfig.Config) []string {
	return normalizeTopics([]string{
		cfg.KafkaTopicDeviceHeartbeat,
		cfg.KafkaTopicWANStatus,
	})
}

func NewKafkaConsumer(cfg KafkaConsumerConfig) (*KafkaConsumer, error) {
	brokers := parseBootstrapServers(cfg.BootstrapServers)
	if len(brokers) == 0 {
		return nil, newKafkaConsumeError(ConsumeErrorInvalidConfig, ConsumedEvent{}, errors.New("kafka consumer requires at least one bootstrap server"))
	}

	groupID := strings.TrimSpace(cfg.GroupID)
	if groupID == "" {
		return nil, newKafkaConsumeError(ConsumeErrorInvalidConfig, ConsumedEvent{}, errors.New("kafka consumer requires consumer group id"))
	}

	topics := normalizeTopics(cfg.Topics)
	if len(topics) == 0 {
		return nil, newKafkaConsumeError(ConsumeErrorInvalidConfig, ConsumedEvent{}, errors.New("kafka consumer requires at least one topic"))
	}

	readTimeout := cfg.ReadTimeout
	if readTimeout <= 0 {
		readTimeout = 5 * time.Second
	}
	commitTimeout := cfg.CommitTimeout
	if commitTimeout <= 0 {
		commitTimeout = 5 * time.Second
	}

	return &KafkaConsumer{
		reader: kafka.NewReader(kafka.ReaderConfig{
			Brokers:          brokers,
			GroupID:          groupID,
			GroupTopics:      topics,
			MinBytes:         1,
			MaxBytes:         10e6,
			MaxWait:          readTimeout,
			ReadBatchTimeout: readTimeout,
			CommitInterval:   0,
			StartOffset:      kafka.FirstOffset,
		}),
		groupID:       groupID,
		commitTimeout: commitTimeout,
	}, nil
}

func NewKafkaConsumerWithReader(reader kafkaMessageReader) (*KafkaConsumer, error) {
	if reader == nil {
		return nil, newKafkaConsumeError(ConsumeErrorInvalidConfig, ConsumedEvent{}, errors.New("kafka consumer requires reader"))
	}
	return &KafkaConsumer{reader: reader, groupID: "test", commitTimeout: 5 * time.Second}, nil
}

func (c *KafkaConsumer) Consume(ctx context.Context, handler EventHandler) error {
	if c == nil || c.reader == nil {
		return newKafkaConsumeError(ConsumeErrorInvalidConfig, ConsumedEvent{}, errors.New("kafka consumer is not initialized"))
	}
	if handler == nil {
		return newKafkaConsumeError(ConsumeErrorInvalidConfig, ConsumedEvent{}, errors.New("kafka consumer requires handler"))
	}

	for {
		if err := ctx.Err(); err != nil {
			return err
		}

		msg, err := c.reader.FetchMessage(ctx)
		if err != nil {
			if ctxErr := ctx.Err(); ctxErr != nil {
				return ctxErr
			}
			return newKafkaConsumeError(ConsumeErrorFetch, ConsumedEvent{}, err)
		}

		event := consumedEventFromKafkaMessage(msg)
		c.recordConsumed(event)
		if err := handler(ctx, event); err != nil {
			return newKafkaConsumeError(ConsumeErrorHandler, event, err)
		}
		if err := c.commit(ctx, msg); err != nil {
			return newKafkaConsumeError(ConsumeErrorCommit, event, err)
		}
	}
}

func (c *KafkaConsumer) Close() error {
	if c == nil || c.reader == nil {
		return nil
	}
	return c.reader.Close()
}

func (c *KafkaConsumer) commit(ctx context.Context, msg kafka.Message) error {
	commitCtx, cancel := context.WithTimeout(context.WithoutCancel(ctx), c.commitTimeout)
	defer cancel()
	if err := c.reader.CommitMessages(commitCtx, msg); err != nil {
		return err
	}
	c.recordCommitted(consumedEventFromKafkaMessage(msg))
	return nil
}

func (c *KafkaConsumer) recordConsumed(event ConsumedEvent) {
	group, topic, partition := c.metricLabels(event)
	kafkaConsumerLastConsumedOffset.WithLabelValues(group, topic, partition).Set(float64(event.Offset))
	if !event.Time.IsZero() {
		age := time.Since(event.Time).Seconds()
		if age < 0 {
			age = 0
		}
		kafkaConsumerMessageAgeSeconds.WithLabelValues(group, topic, partition).Set(age)
	}

	stats := c.reader.Stats()
	if stats.Lag >= 0 {
		kafkaConsumerReaderLagMessages.WithLabelValues(group, topic, partition).Set(float64(stats.Lag))
	}
}

func (c *KafkaConsumer) recordCommitted(event ConsumedEvent) {
	group, topic, partition := c.metricLabels(event)
	kafkaConsumerLastCommittedOffset.WithLabelValues(group, topic, partition).Set(float64(event.Offset))
}

func (c *KafkaConsumer) metricLabels(event ConsumedEvent) (string, string, string) {
	group := strings.TrimSpace(c.groupID)
	if group == "" {
		group = "unknown"
	}
	topic := strings.TrimSpace(event.Topic)
	if topic == "" {
		topic = "unknown"
	}
	return group, topic, strconv.Itoa(event.Partition)
}

func consumedEventFromKafkaMessage(msg kafka.Message) ConsumedEvent {
	return ConsumedEvent{
		Topic:     msg.Topic,
		Key:       string(msg.Key),
		Value:     append([]byte(nil), msg.Value...),
		Time:      msg.Time,
		Partition: msg.Partition,
		Offset:    msg.Offset,
	}
}

func normalizeTopics(topics []string) []string {
	normalized := make([]string, 0, len(topics))
	seen := map[string]struct{}{}
	for _, topic := range topics {
		trimmed := strings.TrimSpace(topic)
		if trimmed == "" {
			continue
		}
		if _, exists := seen[trimmed]; exists {
			continue
		}
		seen[trimmed] = struct{}{}
		normalized = append(normalized, trimmed)
	}
	return normalized
}

func newKafkaConsumeError(kind ConsumeErrorKind, event ConsumedEvent, err error) error {
	if err == nil {
		err = fmt.Errorf("unknown kafka consume error")
	}
	return &KafkaConsumeError{
		Kind:      kind,
		Topic:     event.Topic,
		Key:       event.Key,
		Partition: event.Partition,
		Offset:    event.Offset,
		Err:       err,
	}
}
