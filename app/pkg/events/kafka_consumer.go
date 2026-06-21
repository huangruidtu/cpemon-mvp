package events

import (
	"context"
	"errors"
	"fmt"
	"strconv"
	"strings"
	"time"

	"github.com/segmentio/kafka-go"

	appconfig "github.com/huangruidtu/cpemon-mvp/app/pkg/config"
)

type kafkaMessageReader interface {
	FetchMessage(ctx context.Context) (kafka.Message, error)
	Close() error
}

// KafkaConsumer consumes normalized CPEmon events from Kafka and exposes them
// through the EventConsumer application boundary.
type KafkaConsumer struct {
	reader kafkaMessageReader
}

type KafkaConsumerConfig struct {
	BootstrapServers string
	GroupID          string
	Topics           []string
	ReadTimeout      time.Duration
}

type ConsumeErrorKind string

const (
	ConsumeErrorInvalidConfig ConsumeErrorKind = "invalid_config"
	ConsumeErrorFetch         ConsumeErrorKind = "fetch_error"
	ConsumeErrorHandler       ConsumeErrorKind = "handler_error"
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
	}, nil
}

func NewKafkaConsumerWithReader(reader kafkaMessageReader) (*KafkaConsumer, error) {
	if reader == nil {
		return nil, newKafkaConsumeError(ConsumeErrorInvalidConfig, ConsumedEvent{}, errors.New("kafka consumer requires reader"))
	}
	return &KafkaConsumer{reader: reader}, nil
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
		if err := handler(ctx, event); err != nil {
			return newKafkaConsumeError(ConsumeErrorHandler, event, err)
		}
	}
}

func (c *KafkaConsumer) Close() error {
	if c == nil || c.reader == nil {
		return nil
	}
	return c.reader.Close()
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
