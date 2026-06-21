package config

import (
	"log"
	"os"
	"strconv"
	"time"
)

type Config struct {
	DBDSN          string        // MySQL DSN. Treat as secret material.
	HTTPAddr       string        // HTTP listen address, for example :8080.
	WorkerInterval time.Duration // Background worker loop interval.
	BatchSize      int           // Number of queued rows to process per batch.
	HMACSecret     string        // HMAC key used by acs-ingest.
}

// getenv returns an environment variable or the supplied default.
func getenv(key, def string) string {
	if v := os.Getenv(key); v != "" {
		return v
	}
	return def
}

func Load() Config {
	var cfg Config

	// DB_DSN may include credentials, so never log the raw value.
	cfg.DBDSN = getenv("DB_DSN", "root:password@tcp(127.0.0.1:3306)/cpemon?parseTime=true")
	cfg.HTTPAddr = getenv("HTTP_ADDR", ":8080")

	intervalStr := getenv("WORKER_INTERVAL", "1s")
	if d, err := time.ParseDuration(intervalStr); err == nil {
		cfg.WorkerInterval = d
	} else {
		log.Printf("invalid WORKER_INTERVAL=%q, fallback to 1s", intervalStr)
		cfg.WorkerInterval = time.Second
	}

	batchStr := getenv("BATCH_SIZE", "50")
	if n, err := strconv.Atoi(batchStr); err == nil && n > 0 {
		cfg.BatchSize = n
	} else {
		log.Printf("invalid BATCH_SIZE=%q, fallback to 50", batchStr)
		cfg.BatchSize = 50
	}

	cfg.HMACSecret = getenv("HMAC_SECRET", "")

	log.Printf("config loaded: DB_DSN_set=%t HTTPAddr=%s WorkerInterval=%s BatchSize=%d",
		cfg.DBDSN != "", cfg.HTTPAddr, cfg.WorkerInterval, cfg.BatchSize)

	return cfg
}
