# Kafka Topic Naming Convention

## Purpose

This document defines the CPEmon Kafka topic naming convention.

Covered task:

- `CCPU-75`: Document Kafka topic naming convention.

## Naming Pattern

Use:

```text
cpemon.<domain>.<event-family>.v<major>
```

Examples:

```text
cpemon.device.heartbeat.v1
cpemon.wan.status.v1
cpemon.deadletter.v1
```

## Field Meaning

| Segment | Meaning | Example |
| --- | --- | --- |
| `cpemon` | Product/system prefix. | `cpemon` |
| `<domain>` | Business or platform domain. | `device`, `wan`, `deadletter` |
| `<event-family>` | Event family or purpose. | `heartbeat`, `status` |
| `v<major>` | Major compatibility version. | `v1` |

## Rules

- Use lowercase letters, numbers, and dots.
- Keep topic names stable once producers and consumers depend on them.
- Use singular domain names unless the domain is naturally plural.
- Prefer business meaning over implementation detail.
- Include a major version suffix.
- Do not include environment names such as `dev`, `stage`, or `prod` in topic names.
- Do not include broker, namespace, chart, or cluster names in topic names.
- Do not include producer service names unless the topic is truly service-owned rather than domain-owned.

## Good Examples

```text
cpemon.device.heartbeat.v1
cpemon.wan.status.v1
cpemon.deadletter.v1
```

Why they are good:

- product prefix is clear
- domain is clear
- event purpose is clear
- version is explicit
- names are not tied to a broker implementation

## Bad Examples

```text
heartbeat
cpemon-api-heartbeat
dev.cpemon.device.heartbeat
kafka.cpemon.device.heartbeat
cpemon.device.heartbeat
cpemon.device.heartbeat.v1.us-east-1
```

Why they are bad:

- `heartbeat` is too generic.
- `cpemon-api-heartbeat` couples the topic to a producer service.
- `dev.cpemon.device.heartbeat` mixes environment with the logical topic name.
- `kafka.cpemon.device.heartbeat` leaks infrastructure into the topic name.
- `cpemon.device.heartbeat` has no version.
- `cpemon.device.heartbeat.v1.us-east-1` mixes region/routing into the core logical name.

## Versioning Rule

The suffix is a major compatibility version:

```text
v1
v2
```

Use a new major version when consumers cannot safely read the old and new event shapes with the same logic.

Examples that may require a new major version:

- required field removed
- field meaning changed
- event semantics changed
- payload format changed incompatibly
- partition key strategy changed in a way consumers cannot tolerate

Examples that usually do not require a new topic version:

- optional field added
- documentation improved
- producer adds a field that old consumers ignore
- retention changed without payload compatibility impact

## Environment Rule

Do not put environment names in topic names.

Prefer separate clusters, namespaces, accounts, or Helm values per environment:

```text
dev cluster topic: cpemon.device.heartbeat.v1
prod cluster topic: cpemon.device.heartbeat.v1
```

This keeps application code and dashboards stable across environments.

## Dead-Letter Convention

Use:

```text
cpemon.deadletter.v1
```

This is the first shared dead-letter topic for Step 1.

Later, if failures need stronger ownership boundaries, the project can split dead-letter topics by domain:

```text
cpemon.device.deadletter.v1
cpemon.wan.deadletter.v1
```

The dead-letter event should eventually include:

- source topic
- original key
- original payload
- failure reason
- failure timestamp
- producer or consumer component
- retry count if applicable

## Ownership

Topic ownership belongs to the platform/application contract, not to a single line of producer code.

For each topic, document:

- owner
- producer(s)
- consumer(s)
- retention
- partition count
- replication factor
- compatibility version
- dead-letter behavior

For Story 8, the owner is the CPEmon platform upgrade work. Application-specific ownership is deferred until producer and consumer integration exists.

## Interview Summary

I used topic names as platform contracts. The pattern `cpemon.<domain>.<event-family>.v<major>` makes ownership and compatibility visible. I avoided environment names and broker implementation details because those belong in deployment configuration, not the logical event name. Version suffixes let me introduce incompatible event changes deliberately, and the dead-letter convention gives failures an explicit operational path instead of hiding them in logs.
