package config

import (
	"log"
	"os"
	"strconv"
	"time"
)

type Config struct {
	DBDSN                     string        // MySQL DSN. Treat as secret material.
	HTTPAddr                  string        // HTTP listen address, for example :8080.
	WorkerInterval            time.Duration // Background worker loop interval.
	BatchSize                 int           // Number of queued rows to process per batch.
	HMACSecret                string        // HMAC key used by acs-ingest.
	KafkaProducerEnabled      bool          // Enables app-side Kafka producer behavior.
	KafkaBootstrapServers     string        // Kafka bootstrap servers.
	KafkaTopicDeviceHeartbeat string        // Topic for normalized heartbeat events.
	KafkaTopicWANStatus       string        // Topic for normalized WAN status events.
	KafkaTopicDeadletter      string        // Topic for failed/unprocessable events.
	KafkaProducerTimeout      time.Duration // Per-publish timeout.
	KafkaProducerMaxRetries   int           // Max publish retry attempts.
}

// getenv returns an environment variable or the supplied default.
func getenv(key, def string) string {
	if v := os.Getenv(key); v != "" {
		return v
	}
	return def
}

func getenvBool(key string, def bool) bool {
	v := os.Getenv(key)
	if v == "" {
		return def
	}
	parsed, err := strconv.ParseBool(v)
	if err != nil {
		log.Printf("invalid %s=%q, fallback to %t", key, v, def)
		return def
	}
	return parsed
}

func getenvDuration(key string, def time.Duration) time.Duration {
	v := os.Getenv(key)
	if v == "" {
		return def
	}
	parsed, err := time.ParseDuration(v)
	if err != nil {
		log.Printf("invalid %s=%q, fallback to %s", key, v, def)
		return def
	}
	return parsed
}

func getenvPositiveInt(key string, def int) int {
	v := os.Getenv(key)
	if v == "" {
		return def
	}
	parsed, err := strconv.Atoi(v)
	if err != nil || parsed <= 0 {
		log.Printf("invalid %s=%q, fallback to %d", key, v, def)
		return def
	}
	return parsed
}

func Load() Config {
	var cfg Config

	// DB_DSN may include credentials, so never log the raw value.
	cfg.DBDSN = getenv("DB_DSN", "root:password@tcp(127.0.0.1:3306)/cpemon?parseTime=true")
	cfg.HTTPAddr = getenv("HTTP_ADDR", ":8080")

	cfg.WorkerInterval = getenvDuration("WORKER_INTERVAL", time.Second)
	cfg.BatchSize = getenvPositiveInt("BATCH_SIZE", 50)
	cfg.HMACSecret = getenv("HMAC_SECRET", "")

	cfg.KafkaProducerEnabled = getenvBool("KAFKA_PRODUCER_ENABLED", false)
	cfg.KafkaBootstrapServers = getenv("KAFKA_BOOTSTRAP_SERVERS", "kafka.kafka.svc.cluster.local:9092")
	cfg.KafkaTopicDeviceHeartbeat = getenv("KAFKA_TOPIC_DEVICE_HEARTBEAT", "cpemon.device.heartbeat.v1")
	cfg.KafkaTopicWANStatus = getenv("KAFKA_TOPIC_WAN_STATUS", "cpemon.wan.status.v1")
	cfg.KafkaTopicDeadletter = getenv("KAFKA_TOPIC_DEADLETTER", "cpemon.deadletter.v1")
	cfg.KafkaProducerTimeout = getenvDuration("KAFKA_PRODUCER_TIMEOUT", 5*time.Second)
	cfg.KafkaProducerMaxRetries = getenvPositiveInt("KAFKA_PRODUCER_MAX_RETRIES", 3)

	log.Printf("config loaded: DB_DSN_set=%t HTTPAddr=%s WorkerInterval=%s BatchSize=%d KafkaProducerEnabled=%t KafkaBootstrapServers_set=%t KafkaProducerTimeout=%s KafkaProducerMaxRetries=%d",
		cfg.DBDSN != "", cfg.HTTPAddr, cfg.WorkerInterval, cfg.BatchSize, cfg.KafkaProducerEnabled, cfg.KafkaBootstrapServers != "", cfg.KafkaProducerTimeout, cfg.KafkaProducerMaxRetries)

	return cfg
}
