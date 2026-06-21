package events

import (
	"context"
	"encoding/json"
	"errors"
	"fmt"
	"strings"
	"time"

	"github.com/segmentio/kafka-go"

	appconfig "github.com/huangruidtu/cpemon-mvp/app/pkg/config"
)

type kafkaMessageWriter interface {
	WriteMessages(ctx context.Context, msgs ...kafka.Message) error
	Close() error
}

// KafkaProducer publishes normalized CPEmon events to Kafka.
type KafkaProducer struct {
	writer  kafkaMessageWriter
	timeout time.Duration
}

type KafkaProducerConfig struct {
	BootstrapServers string
	Timeout          time.Duration
}

func NewKafkaProducerFromConfig(cfg appconfig.Config) (*KafkaProducer, error) {
	return NewKafkaProducer(KafkaProducerConfig{
		BootstrapServers: cfg.KafkaBootstrapServers,
		Timeout:          cfg.KafkaProducerTimeout,
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
		timeout: timeout,
	}, nil
}

func NewKafkaProducerWithWriter(writer kafkaMessageWriter, timeout time.Duration) (*KafkaProducer, error) {
	if writer == nil {
		return nil, errors.New("kafka producer requires writer")
	}
	if timeout <= 0 {
		timeout = 5 * time.Second
	}
	return &KafkaProducer{writer: writer, timeout: timeout}, nil
}

func (p *KafkaProducer) Publish(ctx context.Context, event PublishableEvent) error {
	if p == nil || p.writer == nil {
		return errors.New("kafka producer is not initialized")
	}
	if event == nil {
		return errors.New("kafka producer requires event")
	}

	topic := strings.TrimSpace(event.Topic())
	if topic == "" {
		return errors.New("kafka producer requires event topic")
	}

	key := strings.TrimSpace(event.Key())
	if key == "" {
		return errors.New("kafka producer requires event key")
	}

	payload, err := json.Marshal(event)
	if err != nil {
		return fmt.Errorf("marshal kafka event: %w", err)
	}

	writeCtx := ctx
	cancel := func() {}
	if p.timeout > 0 {
		writeCtx, cancel = context.WithTimeout(ctx, p.timeout)
	}
	defer cancel()

	if err := p.writer.WriteMessages(writeCtx, kafka.Message{
		Topic: topic,
		Key:   []byte(key),
		Value: payload,
		Time:  time.Now().UTC(),
	}); err != nil {
		return fmt.Errorf("write kafka message topic=%s key=%s: %w", topic, key, err)
	}

	return nil
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
