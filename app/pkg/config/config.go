package config

import (
	"log"
	"os"
	"strconv"
	"time"
)

type Config struct {
	DBDSN          string        // MySQL DSN
	HTTPAddr       string        // HTTP 监听地址，例如 :8080
	WorkerInterval time.Duration // writer 等后台循环的间隔
	BatchSize      int           // 每轮处理多少条队列（writer 用）
	HMACSecret     string        // acs-ingest 用的 HMAC 密钥
}

// 小工具：带默认值的 getenv
func getenv(key, def string) string {
	if v := os.Getenv(key); v != "" {
		return v
	}
	return def
}

func Load() Config {
	var cfg Config

	// DB 连接串（可以通过环境变量覆盖）
	cfg.DBDSN = getenv("DB_DSN", "root:password@tcp(127.0.0.1:3306)/cpemon?parseTime=true")

	// HTTP 监听地址，默认 :8080
	cfg.HTTPAddr = getenv("HTTP_ADDR", ":8080")

	// 后台循环间隔，默认 1s
	intervalStr := getenv("WORKER_INTERVAL", "1s")
	if d, err := time.ParseDuration(intervalStr); err == nil {
		cfg.WorkerInterval = d
	} else {
		log.Printf("invalid WORKER_INTERVAL=%q, fallback to 1s", intervalStr)
		cfg.WorkerInterval = time.Second
	}

	// 每轮处理的 batch size，默认 50
	batchStr := getenv("BATCH_SIZE", "50")
	if n, err := strconv.Atoi(batchStr); err == nil && n > 0 {
		cfg.BatchSize = n
	} else {
		log.Printf("invalid BATCH_SIZE=%q, fallback to 50", batchStr)
		cfg.BatchSize = 50
	}

	// HMAC 密钥，acs-ingest 可用；为空则跳过验签
	cfg.HMACSecret = getenv("HMAC_SECRET", "")

	log.Printf("config loaded: DBDSN=%s HTTPAddr=%s WorkerInterval=%s BatchSize=%d",
		cfg.DBDSN, cfg.HTTPAddr, cfg.WorkerInterval, cfg.BatchSize)

	return cfg
}
