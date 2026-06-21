# cpemon-api Kafka-Updated Status Validation

## Purpose

This runbook proves that Kafka-updated device state is visible through the
existing `cpemon-api` read path:

```text
Kafka topic -> cpemon-writer -> MySQL cpe_status -> cpemon-api GET /api/cpe/:sn
```

Covered task:

- `CCPU-172`: Verify API reads Kafka-updated device status.

## Preconditions

Complete the Kafka-to-DB validation first:

```text
ops/runbooks/cpemon-writer-kafka-to-db-validation.md
```

Expected validated database state for the sample device:

| Field | Expected |
| --- | --- |
| `sn` | `TEST-CPE-KAFKA-DB-001` |
| `last_seen` | WAN status event timestamp from the latest Kafka event |
| `wan_ip` | `10.0.0.13` |
| `sw_version` | `v1.0-demo` |

Required platform state:

* `cpemon-api` pod is running.
* `cpemon-api` can read the same MySQL database updated by `cpemon-writer`.
* `cpemon-writer` has processed the heartbeat and WAN status Kafka messages.

## Verify API Endpoint

Port-forward the API service:

```powershell
kubectl port-forward -n cpemon svc/cpemon-api 8081:8080
```

Read the Kafka-updated device status:

```powershell
$status = Invoke-RestMethod `
  -Method Get `
  -Uri "http://127.0.0.1:8081/api/cpe/TEST-CPE-KAFKA-DB-001"

$status | ConvertTo-Json -Depth 5
```

Expected response shape:

```json
{
  "SN": "TEST-CPE-KAFKA-DB-001",
  "LastSeen": "2026-06-22T10:05:00Z",
  "WANIP": "10.0.0.13",
  "SWVersion": "v1.0-demo"
}
```

Exact timestamp formatting depends on Go JSON encoding for `time.Time`, but
the value should reflect the latest Kafka event written by `cpemon-writer`.

## Cross-Check Database And API

Query MySQL:

```sql
SELECT sn, last_seen, wan_ip, sw_version
FROM cpe_status
WHERE sn = 'TEST-CPE-KAFKA-DB-001';
```

Compare with API fields:

| MySQL Column | API Field |
| --- | --- |
| `sn` | `SN` |
| `last_seen` | `LastSeen` |
| `wan_ip` | `WANIP` |
| `sw_version` | `SWVersion` |

The API should be a read view over the same `cpe_status` row. If MySQL is
correct but the API response is stale or missing, debug API DB connectivity,
not Kafka.

## Verify List Endpoint

The list endpoint should also include the same device:

```powershell
Invoke-RestMethod "http://127.0.0.1:8081/api/cpe?offset=0&limit=50" |
  ConvertTo-Json -Depth 5
```

Look for:

```text
TEST-CPE-KAFKA-DB-001
10.0.0.13
v1.0-demo
```

## Responsibility Split

| Layer | Proof |
| --- | --- |
| Producer/Kafka | Message exists in `cpemon.device.heartbeat.v1` or `cpemon.wan.status.v1`. |
| Writer | `event=writer_kafka_process result=success` appears and offsets advance. |
| Database | `cpe_status` row contains expected `last_seen`, `wan_ip`, `sw_version`. |
| API | `GET /api/cpe/:sn` returns the same row fields. |

## Troubleshooting

If API returns `404`:

1. Confirm MySQL contains the row.
2. Confirm `cpemon-api` and `cpemon-writer` point at the same `DB_DSN`.
3. Confirm the request path uses the exact serial number.

If API returns old values:

1. Confirm the WAN status event timestamp is newer than the stored `last_seen`.
2. Confirm writer logs show successful WAN status processing.
3. Confirm the SQL row changed before querying the API.

If API returns `500`:

1. Check `cpemon-api` logs for `handleGetCPE: db error`.
2. Check the API DB Secret and `DB_DSN`.
3. Use the API DB connection runbook.

## Validation Boundary

Repository validation:

```powershell
make cpemon-api-kafka-status-validation-check
```

This validates the runbook, API query path, SQL/API field mapping, docs, and
expected evidence. It does not prove live API behavior. Live proof requires
running the Kafka-to-DB validation first, then calling the API endpoint against
a running deployment.

## Interview Summary

This validation proves the read side of the migration. Kafka is not useful by
itself; the user-facing API must read the state that the Kafka consumer wrote.
The clean proof chain is: Kafka event, writer success log, MySQL row, API JSON
response.
