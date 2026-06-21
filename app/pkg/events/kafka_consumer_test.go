package events

import (
	"context"
	"errors"
	"strings"
	"testing"
	"time"

	"github.com/segmentio/kafka-go"

	appconfig "github.com/huangruidtu/cpemon-mvp/app/pkg/config"
)

type fakeKafkaReader struct {
	messages []kafka.Message
	err      error
	closed   bool
}

func (r *fakeKafkaReader) FetchMessage(ctx context.Context) (kafka.Message, error) {
	if err := ctx.Err(); err != nil {
		return kafka.Message{}, err
	}
	if len(r.messages) == 0 {
		if r.err != nil {
			return kafka.Message{}, r.err
		}
		return kafka.Message{}, context.Canceled
	}
	msg := r.messages[0]
	r.messages = r.messages[1:]
	return msg, nil
}

func (r *fakeKafkaReader) Close() error {
	r.closed = true
	return nil
}

func TestNewKafkaConsumerRejectsInvalidConfig(t *testing.T) {
	tests := []struct {
		name string
		cfg  KafkaConsumerConfig
		want string
	}{
		{
			name: "missing bootstrap servers",
			cfg: KafkaConsumerConfig{
				GroupID: "cpemon-writer",
				Topics:  []string{DeviceHeartbeatTopic},
			},
			want: "bootstrap",
		},
		{
			name: "missing group id",
			cfg: KafkaConsumerConfig{
				BootstrapServers: "localhost:9092",
				Topics:           []string{DeviceHeartbeatTopic},
			},
			want: "group id",
		},
		{
			name: "missing topics",
			cfg: KafkaConsumerConfig{
				BootstrapServers: "localhost:9092",
				GroupID:          "cpemon-writer",
			},
			want: "topic",
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			_, err := NewKafkaConsumer(tt.cfg)
			if err == nil {
				t.Fatal("expected error")
			}
			if !strings.Contains(err.Error(), tt.want) {
				t.Fatalf("error = %q, want it to contain %q", err.Error(), tt.want)
			}
		})
	}
}

func TestNewKafkaConsumerFromConfig(t *testing.T) {
	consumer, err := NewKafkaConsumerFromConfig(appconfig.Config{
		KafkaBootstrapServers:     "localhost:9092",
		KafkaConsumerGroupID:      "cpemon-writer",
		KafkaTopicDeviceHeartbeat: DeviceHeartbeatTopic,
		KafkaTopicWANStatus:       WANStatusTopic,
		KafkaConsumerReadTimeout:  250 * time.Millisecond,
	})
	if err != nil {
		t.Fatalf("NewKafkaConsumerFromConfig returned error: %v", err)
	}
	if consumer == nil {
		t.Fatal("consumer is nil")
	}
	if err := consumer.Close(); err != nil {
		t.Fatalf("Close returned error: %v", err)
	}
}

func TestKafkaConsumerTopicsFromConfigIncludesHeartbeatTopic(t *testing.T) {
	topics := KafkaConsumerTopicsFromConfig(appconfig.Config{
		KafkaTopicDeviceHeartbeat: DeviceHeartbeatTopic,
		KafkaTopicWANStatus:       "",
	})

	if len(topics) != 1 {
		t.Fatalf("topics = %#v, want exactly heartbeat topic", topics)
	}
	if topics[0] != DeviceHeartbeatTopic {
		t.Fatalf("topics[0] = %q, want %q", topics[0], DeviceHeartbeatTopic)
	}
}

func TestKafkaConsumerTopicsFromConfigIncludesWANStatusTopic(t *testing.T) {
	topics := KafkaConsumerTopicsFromConfig(appconfig.Config{
		KafkaTopicDeviceHeartbeat: "",
		KafkaTopicWANStatus:       WANStatusTopic,
	})

	if len(topics) != 1 {
		t.Fatalf("topics = %#v, want exactly WAN status topic", topics)
	}
	if topics[0] != WANStatusTopic {
		t.Fatalf("topics[0] = %q, want %q", topics[0], WANStatusTopic)
	}
}

func TestNewKafkaConsumerWithReaderRequiresReader(t *testing.T) {
	_, err := NewKafkaConsumerWithReader(nil)
	if err == nil {
		t.Fatal("expected error")
	}
}

func TestKafkaConsumerConsumesMessageThroughBoundary(t *testing.T) {
	eventTime := time.Date(2026, 6, 22, 9, 15, 0, 0, time.UTC)
	reader := &fakeKafkaReader{
		messages: []kafka.Message{
			{
				Topic:     DeviceHeartbeatTopic,
				Key:       []byte("CPE-001"),
				Value:     []byte(`{"event_type":"device.heartbeat"}`),
				Time:      eventTime,
				Partition: 3,
				Offset:    77,
			},
		},
	}
	consumer, err := NewKafkaConsumerWithReader(reader)
	if err != nil {
		t.Fatalf("NewKafkaConsumerWithReader returned error: %v", err)
	}

	ctx, cancel := context.WithCancel(context.Background())
	defer cancel()
	var handled []ConsumedEvent
	err = consumer.Consume(ctx, func(ctx context.Context, event ConsumedEvent) error {
		handled = append(handled, event)
		cancel()
		return nil
	})
	if !errors.Is(err, context.Canceled) {
		t.Fatalf("Consume error = %v, want context.Canceled after handler cancels", err)
	}

	if len(handled) != 1 {
		t.Fatalf("handled events = %d, want 1", len(handled))
	}
	got := handled[0]
	if got.Topic != DeviceHeartbeatTopic || got.Key != "CPE-001" {
		t.Fatalf("event topic/key = %q/%q", got.Topic, got.Key)
	}
	if string(got.Value) != `{"event_type":"device.heartbeat"}` {
		t.Fatalf("event value = %q", string(got.Value))
	}
	if got.Partition != 3 || got.Offset != 77 {
		t.Fatalf("event metadata partition=%d offset=%d, want 3/77", got.Partition, got.Offset)
	}
}

func TestKafkaConsumerReturnsFetchError(t *testing.T) {
	readerErr := errors.New("broker unavailable")
	consumer, err := NewKafkaConsumerWithReader(&fakeKafkaReader{err: readerErr})
	if err != nil {
		t.Fatalf("NewKafkaConsumerWithReader returned error: %v", err)
	}

	err = consumer.Consume(context.Background(), func(ctx context.Context, event ConsumedEvent) error {
		t.Fatal("handler should not run on fetch error")
		return nil
	})
	if !errors.Is(err, readerErr) {
		t.Fatalf("Consume error = %v, want %v", err, readerErr)
	}
	var consumeErr *KafkaConsumeError
	if !errors.As(err, &consumeErr) {
		t.Fatalf("error type = %T, want *KafkaConsumeError", err)
	}
	if consumeErr.Kind != ConsumeErrorFetch {
		t.Fatalf("kind = %q, want %q", consumeErr.Kind, ConsumeErrorFetch)
	}
}

func TestKafkaConsumerReturnsHandlerErrorWithMessageContext(t *testing.T) {
	handlerErr := errors.New("db write failed")
	reader := &fakeKafkaReader{
		messages: []kafka.Message{
			{
				Topic:     WANStatusTopic,
				Key:       []byte("CPE-002"),
				Value:     []byte(`{"event_type":"wan.status"}`),
				Partition: 4,
				Offset:    99,
			},
		},
	}
	consumer, err := NewKafkaConsumerWithReader(reader)
	if err != nil {
		t.Fatalf("NewKafkaConsumerWithReader returned error: %v", err)
	}

	err = consumer.Consume(context.Background(), func(ctx context.Context, event ConsumedEvent) error {
		return handlerErr
	})
	if !errors.Is(err, handlerErr) {
		t.Fatalf("Consume error = %v, want %v", err, handlerErr)
	}
	text := err.Error()
	for _, token := range []string{"kind=handler_error", "topic=" + WANStatusTopic, "key=CPE-002", "partition=4", "offset=99"} {
		if !strings.Contains(text, token) {
			t.Fatalf("error %q does not contain %q", text, token)
		}
	}
}

func TestKafkaConsumerCloseClosesReader(t *testing.T) {
	reader := &fakeKafkaReader{}
	consumer, err := NewKafkaConsumerWithReader(reader)
	if err != nil {
		t.Fatalf("NewKafkaConsumerWithReader returned error: %v", err)
	}

	if err := consumer.Close(); err != nil {
		t.Fatalf("Close returned error: %v", err)
	}
	if !reader.closed {
		t.Fatal("reader was not closed")
	}
}

func TestNormalizeTopics(t *testing.T) {
	got := normalizeTopics([]string{"", " " + DeviceHeartbeatTopic + " ", WANStatusTopic, DeviceHeartbeatTopic})
	want := []string{DeviceHeartbeatTopic, WANStatusTopic}
	if len(got) != len(want) {
		t.Fatalf("topics = %#v, want %#v", got, want)
	}
	for i := range want {
		if got[i] != want[i] {
			t.Fatalf("topics = %#v, want %#v", got, want)
		}
	}
}
