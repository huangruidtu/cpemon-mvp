package config

import (
	"os"
	"testing"
	"time"
)

func clearKafkaEnv(t *testing.T) {
	t.Helper()

	keys := []string{
		"KAFKA_PRODUCER_ENABLED",
		"KAFKA_BOOTSTRAP_SERVERS",
		"KAFKA_TOPIC_DEVICE_HEARTBEAT",
		"KAFKA_TOPIC_WAN_STATUS",
		"KAFKA_TOPIC_DEADLETTER",
		"KAFKA_PRODUCER_TIMEOUT",
		"KAFKA_PRODUCER_MAX_RETRIES",
	}
	previous := map[string]string{}
	present := map[string]bool{}

	for _, key := range keys {
		if value, ok := os.LookupEnv(key); ok {
			previous[key] = value
			present[key] = true
		}
		if err := os.Unsetenv(key); err != nil {
			t.Fatalf("failed to unset %s: %v", key, err)
		}
	}

	t.Cleanup(func() {
		for _, key := range keys {
			if present[key] {
				_ = os.Setenv(key, previous[key])
			} else {
				_ = os.Unsetenv(key)
			}
		}
	})
}

func TestLoadKafkaProducerDefaults(t *testing.T) {
	clearKafkaEnv(t)

	cfg := Load()

	if cfg.KafkaProducerEnabled {
		t.Fatal("KafkaProducerEnabled = true, want false by default")
	}
	if cfg.KafkaBootstrapServers != "kafka.kafka.svc.cluster.local:9092" {
		t.Fatalf("KafkaBootstrapServers = %q", cfg.KafkaBootstrapServers)
	}
	if cfg.KafkaTopicDeviceHeartbeat != "cpemon.device.heartbeat.v1" {
		t.Fatalf("KafkaTopicDeviceHeartbeat = %q", cfg.KafkaTopicDeviceHeartbeat)
	}
	if cfg.KafkaTopicWANStatus != "cpemon.wan.status.v1" {
		t.Fatalf("KafkaTopicWANStatus = %q", cfg.KafkaTopicWANStatus)
	}
	if cfg.KafkaTopicDeadletter != "cpemon.deadletter.v1" {
		t.Fatalf("KafkaTopicDeadletter = %q", cfg.KafkaTopicDeadletter)
	}
	if cfg.KafkaProducerTimeout != 5*time.Second {
		t.Fatalf("KafkaProducerTimeout = %s, want 5s", cfg.KafkaProducerTimeout)
	}
	if cfg.KafkaProducerMaxRetries != 3 {
		t.Fatalf("KafkaProducerMaxRetries = %d, want 3", cfg.KafkaProducerMaxRetries)
	}
}

func TestLoadKafkaProducerOverrides(t *testing.T) {
	clearKafkaEnv(t)

	t.Setenv("KAFKA_PRODUCER_ENABLED", "true")
	t.Setenv("KAFKA_BOOTSTRAP_SERVERS", "localhost:9092")
	t.Setenv("KAFKA_TOPIC_DEVICE_HEARTBEAT", "test.device.heartbeat.v1")
	t.Setenv("KAFKA_TOPIC_WAN_STATUS", "test.wan.status.v1")
	t.Setenv("KAFKA_TOPIC_DEADLETTER", "test.deadletter.v1")
	t.Setenv("KAFKA_PRODUCER_TIMEOUT", "750ms")
	t.Setenv("KAFKA_PRODUCER_MAX_RETRIES", "7")

	cfg := Load()

	if !cfg.KafkaProducerEnabled {
		t.Fatal("KafkaProducerEnabled = false, want true")
	}
	if cfg.KafkaBootstrapServers != "localhost:9092" {
		t.Fatalf("KafkaBootstrapServers = %q", cfg.KafkaBootstrapServers)
	}
	if cfg.KafkaTopicDeviceHeartbeat != "test.device.heartbeat.v1" {
		t.Fatalf("KafkaTopicDeviceHeartbeat = %q", cfg.KafkaTopicDeviceHeartbeat)
	}
	if cfg.KafkaTopicWANStatus != "test.wan.status.v1" {
		t.Fatalf("KafkaTopicWANStatus = %q", cfg.KafkaTopicWANStatus)
	}
	if cfg.KafkaTopicDeadletter != "test.deadletter.v1" {
		t.Fatalf("KafkaTopicDeadletter = %q", cfg.KafkaTopicDeadletter)
	}
	if cfg.KafkaProducerTimeout != 750*time.Millisecond {
		t.Fatalf("KafkaProducerTimeout = %s, want 750ms", cfg.KafkaProducerTimeout)
	}
	if cfg.KafkaProducerMaxRetries != 7 {
		t.Fatalf("KafkaProducerMaxRetries = %d, want 7", cfg.KafkaProducerMaxRetries)
	}
}

func TestLoadKafkaProducerInvalidValuesFallback(t *testing.T) {
	clearKafkaEnv(t)

	t.Setenv("KAFKA_PRODUCER_ENABLED", "not-bool")
	t.Setenv("KAFKA_PRODUCER_TIMEOUT", "not-duration")
	t.Setenv("KAFKA_PRODUCER_MAX_RETRIES", "0")

	cfg := Load()

	if cfg.KafkaProducerEnabled {
		t.Fatal("KafkaProducerEnabled = true, want false fallback")
	}
	if cfg.KafkaProducerTimeout != 5*time.Second {
		t.Fatalf("KafkaProducerTimeout = %s, want 5s fallback", cfg.KafkaProducerTimeout)
	}
	if cfg.KafkaProducerMaxRetries != 3 {
		t.Fatalf("KafkaProducerMaxRetries = %d, want 3 fallback", cfg.KafkaProducerMaxRetries)
	}
}
