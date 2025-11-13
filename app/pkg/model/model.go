package model

import "time"

// IngestEvent represents a row in the ingest_events table.
//
// CREATE TABLE ingest_events (
//   id BIGINT PRIMARY KEY AUTO_INCREMENT,
//   source ENUM('acs','cpe') NOT NULL DEFAULT 'acs',
//   sn VARCHAR(64) NOT NULL,
//   event_ts DATETIME(3) NOT NULL,
//   payload JSON NOT NULL,
//   status ENUM('queued','processing','done','dead') NOT NULL DEFAULT 'queued',
//   attempts INT NOT NULL DEFAULT 0,
//   next_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
//   created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
//   updated_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
//   UNIQUE KEY uk_idem (sn,event_ts),
//   KEY ix_status_next (status,next_at)
// );
type IngestEvent struct {
	ID        int64     `db:"id"`
	Source    string    `db:"source"`
	SN        string    `db:"sn"`
	EventTS   time.Time `db:"event_ts"`
	Payload   []byte    `db:"payload"` // JSON, we keep it as raw bytes for now
	Status    string    `db:"status"`
	Attempts  int       `db:"attempts"`
	NextAt    time.Time `db:"next_at"`
	CreatedAt time.Time `db:"created_at"`
	UpdatedAt time.Time `db:"updated_at"`
}

// CPEStatus represents the current status of a CPE.
//
// CREATE TABLE cpe_status (
//   sn VARCHAR(64) PRIMARY KEY,
//   last_seen DATETIME(3),
//   wan_ip VARCHAR(64),
//   sw_version VARCHAR(64),
//   cpu_pct TINYINT, mem_pct TINYINT,
//   updated_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP
// );
type CPEStatus struct {
	SN        string     `db:"sn"`
	LastSeen  *time.Time `db:"last_seen"`  // pointer so it can be NULL
	WANIP     *string    `db:"wan_ip"`     // optional fields as pointers
	SWVersion *string    `db:"sw_version"`
	CPUPct    *int       `db:"cpu_pct"`
	MemPct    *int       `db:"mem_pct"`
	UpdatedAt time.Time  `db:"updated_at"`
}

// CPEStatusHistory represents a historical snapshot of a CPE.
//
// CREATE TABLE cpe_status_history (
//   sn VARCHAR(64) NOT NULL,
//   event_ts DATETIME(3) NOT NULL,
//   last_seen DATETIME(3), wan_ip VARCHAR(64), sw_version VARCHAR(64),
//   cpu_pct TINYINT, mem_pct TINYINT,
//   PRIMARY KEY(sn, event_ts)
// );
type CPEStatusHistory struct {
	SN        string     `db:"sn"`
	EventTS   time.Time  `db:"event_ts"`
	LastSeen  *time.Time `db:"last_seen"`
	WANIP     *string    `db:"wan_ip"`
	SWVersion *string    `db:"sw_version"`
	CPUPct    *int       `db:"cpu_pct"`
	MemPct    *int       `db:"mem_pct"`
}
