package events

import (
	"context"
	"encoding/json"
	"errors"
	"strings"
	"testing"
	"time"

	"github.com/segmentio/kafka-go"

	appconfig "github.com/huangruidtu/cpemon-mvp/app/pkg/config"
	"github.com/huangruidtu/cpemon-mvp/app/pkg/model"
)

type fakeKafkaWriter struct {
	messages []kafka.Message
	err      error
	closed   bool
}

func (w *fakeKafkaWriter) WriteMessages(ctx context.Context, msgs ...kafka.Message) error {
	if err := ctx.Err(); err != nil {
		return err
	}
	if w.err != nil {
		return w.err
	}
	w.messages = append(w.messages, msgs...)
	return nil
}

func (w *fakeKafkaWriter) Close() error {
	w.closed = true
	return nil
}

func TestNewKafkaProducerRejectsMissingBootstrapServers(t *testing.T) {
	_, err := NewKafkaProducer(KafkaProducerConfig{})
	if err == nil {
		t.Fatal("expected error for missing bootstrap servers")
	}
}

func TestNewKafkaProducerFromConfig(t *testing.T) {
	producer, err := NewKafkaProducerFromConfig(appconfig.Config{
		KafkaBootstrapServers:     "localhost:9092",
		KafkaProducerTimeout:      250 * time.Millisecond,
		KafkaTopicDeviceHeartbeat: DeviceHeartbeatTopic,
	})
	if err != nil {
		t.Fatalf("NewKafkaProducerFromConfig returned error: %v", err)
	}
	if producer == nil {
		t.Fatal("producer is nil")
	}
}

func TestKafkaProducerPublishesEvent(t *testing.T) {
	writer := &fakeKafkaWriter{}
	producer, err := NewKafkaProducerWithWriter(writer, time.Second)
	if err != nil {
		t.Fatalf("NewKafkaProducerWithWriter returned error: %v", err)
	}

	heartbeat, err := NewDeviceHeartbeatEvent(model.IngestEvent{
		Source:  "acs",
		SN:      "CPE-001",
		EventTS: time.Date(2026, 6, 21, 10, 30, 0, 0, time.UTC),
	}, time.Date(2026, 6, 21, 10, 31, 0, 0, time.UTC))
	if err != nil {
		t.Fatalf("NewDeviceHeartbeatEvent returned error: %v", err)
	}

	if err := producer.Publish(context.Background(), heartbeat); err != nil {
		t.Fatalf("Publish returned error: %v", err)
	}

	if len(writer.messages) != 1 {
		t.Fatalf("messages = %d, want 1", len(writer.messages))
	}
	msg := writer.messages[0]
	if msg.Topic != DeviceHeartbeatTopic {
		t.Fatalf("topic = %q, want %q", msg.Topic, DeviceHeartbeatTopic)
	}
	if string(msg.Key) != "CPE-001" {
		t.Fatalf("key = %q, want CPE-001", string(msg.Key))
	}

	var decoded map[string]any
	if err := json.Unmarshal(msg.Value, &decoded); err != nil {
		t.Fatalf("message value is not JSON: %v", err)
	}
	if decoded["event_type"] != DeviceHeartbeatEventType {
		t.Fatalf("event_type = %v, want %q", decoded["event_type"], DeviceHeartbeatEventType)
	}
}

func TestKafkaProducerReturnsWriterError(t *testing.T) {
	writer := &fakeKafkaWriter{err: errors.New("broker unavailable")}
	producer, err := NewKafkaProducerWithWriter(writer, time.Second)
	if err != nil {
		t.Fatalf("NewKafkaProducerWithWriter returned error: %v", err)
	}

	heartbeat := DeviceHeartbeatEvent{
		DeviceID: "CPE-001",
	}

	err = producer.Publish(context.Background(), heartbeat)
	if err == nil {
		t.Fatal("expected writer error")
	}
	if !strings.Contains(err.Error(), "topic=") || !strings.Contains(err.Error(), "key=CPE-001") {
		t.Fatalf("error lacks topic/key context: %v", err)
	}
}

func TestKafkaProducerValidatesTopicAndKey(t *testing.T) {
	writer := &fakeKafkaWriter{}
	producer, err := NewKafkaProducerWithWriter(writer, time.Second)
	if err != nil {
		t.Fatalf("NewKafkaProducerWithWriter returned error: %v", err)
	}

	if err := producer.Publish(context.Background(), nil); err == nil {
		t.Fatal("expected error for nil event")
	}
	if err := producer.Publish(context.Background(), eventWithoutTopic{}); err == nil {
		t.Fatal("expected error for missing topic")
	}
	if err := producer.Publish(context.Background(), eventWithoutKey{}); err == nil {
		t.Fatal("expected error for missing key")
	}
}

func TestKafkaProducerCloseClosesWriter(t *testing.T) {
	writer := &fakeKafkaWriter{}
	producer, err := NewKafkaProducerWithWriter(writer, time.Second)
	if err != nil {
		t.Fatalf("NewKafkaProducerWithWriter returned error: %v", err)
	}

	if err := producer.Close(); err != nil {
		t.Fatalf("Close returned error: %v", err)
	}
	if !writer.closed {
		t.Fatal("writer was not closed")
	}
}

func TestParseBootstrapServers(t *testing.T) {
	got := parseBootstrapServers("localhost:9092, kafka:9092 ,,")
	want := []string{"localhost:9092", "kafka:9092"}
	if len(got) != len(want) {
		t.Fatalf("brokers = %#v, want %#v", got, want)
	}
	for i := range want {
		if got[i] != want[i] {
			t.Fatalf("brokers = %#v, want %#v", got, want)
		}
	}
}

type eventWithoutTopic struct{}

func (eventWithoutTopic) Topic() string { return "" }
func (eventWithoutTopic) Key() string   { return "CPE-001" }

type eventWithoutKey struct{}

func (eventWithoutKey) Topic() string { return DeviceHeartbeatTopic }
func (eventWithoutKey) Key() string   { return "" }
