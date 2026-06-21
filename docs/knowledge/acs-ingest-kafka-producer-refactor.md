# acs-ingest Kafka Producer Refactor

## Purpose

Story 9 moves `acs-ingest` toward publishing normalized device events to Kafka.

The first contract is the heartbeat event for topic `cpemon.device.heartbeat.v1`.
The important design decision is that the event is a normalized CPEmon domain
event, not a raw ACS webhook payload.

## Heartbeat Event Contract

Topic:

```text
cpemon.device.heartbeat.v1
```

Message key:

```text
device_id
```

For the current CPEmon model, `device_id` is the ACS serial number. The event
also keeps `serial_number` explicitly so the payload remains easy to inspect.

Payload fields:

| Field | Meaning |
| --- | --- |
| `schema_version` | Contract version. Current value: `v1`. |
| `event_type` | Current value: `device.heartbeat`. |
| `source` | Source system, normally `acs`. |
| `device_id` | Stable Kafka message key and device identity. |
| `serial_number` | Original ACS serial number. |
| `event_ts` | Timestamp from the ACS event, normalized to UTC. |
| `received_at` | Time the ingest service created the normalized event. |
| `status` | Heartbeat status. Current value: `online`. |

Example:

```json
{
  "schema_version": "v1",
  "event_type": "device.heartbeat",
  "source": "acs",
  "device_id": "CPE-001",
  "serial_number": "CPE-001",
  "event_ts": "2026-06-21T10:30:00Z",
  "received_at": "2026-06-21T10:31:00Z",
  "status": "online"
}
```

## Mapping From Current Model

The current `acs-ingest` path builds `model.IngestEvent` with:

* `Source`
* `SN`
* `EventTS`
* raw JSON `Payload`

`NewDeviceHeartbeatEvent` maps that model to the Kafka contract:

* `SN` becomes `device_id` and `serial_number`
* `EventTS` becomes `event_ts`
* `Source` becomes `source`, defaulting to `acs` when absent
* `received_at` is supplied by the caller
* `status` is set to `online`

## Validation Boundary

This subtask defines and tests the heartbeat event schema only.
It does not yet publish to Kafka. Producer implementation, application wiring,
retry/error handling, and live Kafka validation are handled by later subtasks.

## Interview Notes

A strong explanation:

> I introduced the heartbeat schema before the producer because event contracts
> are the stable boundary between services. Kafka topics should carry normalized
> domain events, not raw webhook payloads. That keeps consumers decoupled from
> ACS-specific request shape and lets the team version the contract explicitly.

Key points to mention:

* Topic name follows `cpemon.<domain>.<event-family>.v<major>`.
* The message key is stable device identity, so events for the same device can
  be ordered within a partition.
* The schema records both event time and ingest time.
* The schema is unit-testable without Kafka.

