package admin

import (
    "context"
    "database/sql"
    "time"
)

// 原始 DB 层结构体（对应表字段）
type cpeStatusRow struct {
    SN              string
    WANIP           string
    SWVersion       string
    CPUPct          int
    MemPct          int
    LastHeartbeatAt time.Time
}

type cpeHistoryRow struct {
    SN          string
    WANIP       string
    SWVersion   string
    CPUPct      int
    MemPct      int
    HeartbeatAt time.Time
}

func GetCurrentStatusBySN(ctx context.Context, db *sql.DB, sn string) (*cpeStatusRow, error) {
    const query = `
        SELECT sn, wan_ip, sw_version, cpu_pct, mem_pct, last_heartbeat_at
        FROM cpe_status
        WHERE sn = ?
    `

    row := db.QueryRowContext(ctx, query, sn)

    var r cpeStatusRow
    if err := row.Scan(&r.SN, &r.WANIP, &r.SWVersion, &r.CPUPct, &r.MemPct, &r.LastHeartbeatAt); err != nil {
        if err == sql.ErrNoRows {
            return nil, nil
        }
        return nil, err
    }

    return &r, nil
}

func GetHistoryBySN(ctx context.Context, db *sql.DB, sn string, limit int) ([]cpeHistoryRow, error) {
    const query = `
        SELECT sn, wan_ip, sw_version, cpu_pct, mem_pct, heartbeat_at
        FROM cpe_status_history
        WHERE sn = ?
        ORDER BY heartbeat_at DESC
        LIMIT ?
    `

    rows, err := db.QueryContext(ctx, query, sn, limit)
    if err != nil {
        return nil, err
    }
    defer rows.Close()

    var result []cpeHistoryRow
    for rows.Next() {
        var r cpeHistoryRow
        if err := rows.Scan(&r.SN, &r.WANIP, &r.SWVersion, &r.CPUPct, &r.MemPct, &r.HeartbeatAt); err != nil {
            return nil, err
        }
        result = append(result, r)
    }

    return result, rows.Err()
}

