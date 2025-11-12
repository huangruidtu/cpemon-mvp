-- Ensure DB default charset/collation (safe if already set)
ALTER DATABASE `cpemon`
  CHARACTER SET utf8mb4
  COLLATE utf8mb4_0900_ai_ci;

-- Use the DB
USE `cpemon`;

-- 1) Ingest queue:事件入队+重试/回退
CREATE TABLE IF NOT EXISTS ingest_events (
  id BIGINT PRIMARY KEY AUTO_INCREMENT,
  source ENUM('acs','cpe') NOT NULL DEFAULT 'acs',
  sn VARCHAR(64) NOT NULL,
  event_ts DATETIME(3) NOT NULL,
  payload JSON NOT NULL,
  status ENUM('queued','processing','done','dead') NOT NULL DEFAULT 'queued',
  attempts INT NOT NULL DEFAULT 0,
  next_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  updated_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  UNIQUE KEY uk_idem (sn,event_ts),
  KEY ix_status_next (status,next_at)
) ENGINE=InnoDB
  DEFAULT CHARSET=utf8mb4
  COLLATE=utf8mb4_0900_ai_ci;

-- 2) 快照表：面向读的最新状态
CREATE TABLE IF NOT EXISTS cpe_status (
  sn VARCHAR(64) PRIMARY KEY,
  last_seen DATETIME(3),
  wan_ip VARCHAR(64),
  sw_version VARCHAR(64),
  cpu_pct TINYINT,
  mem_pct TINYINT,
  updated_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP
) ENGINE=InnoDB
  DEFAULT CHARSET=utf8mb4
  COLLATE=utf8mb4_0900_ai_ci;

-- 3) 历史表：面向审计/趋势
CREATE TABLE IF NOT EXISTS cpe_status_history (
  sn VARCHAR(64) NOT NULL,
  event_ts DATETIME(3) NOT NULL,
  last_seen DATETIME(3),
  wan_ip VARCHAR(64),
  sw_version VARCHAR(64),
  cpu_pct TINYINT,
  mem_pct TINYINT,
  PRIMARY KEY(sn, event_ts)
) ENGINE=InnoDB
  DEFAULT CHARSET=utf8mb4
  COLLATE=utf8mb4_0900_ai_ci;

-- 可选：再次确保默认字符集（新表/列都用 utf8mb4）
SET NAMES utf8mb4;
