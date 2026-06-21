# Story 14: Kafka Platform Introduction

## Q1: What is the goal of Story 8 / CCPU-8?

The goal is to introduce Kafka as the platform event buffer for the CPEmon cloud upgrade.

This story focuses on the platform boundary:

- deployment option
- namespace
- installation workflow
- bootstrap server contract
- initial topics
- manual validation
- documentation and interview notes

It does not yet implement application producer or consumer code.

## Q2: What did CCPU-69 decide?

`CCPU-69` decided to use a Helm chart based Kafka deployment for Step 1.

The ADR is:

```text
ADR/cloud-platform-upgrade-kafka-deployment-step1.md
```

## Q3: Why not use Kafka in the original MVP?

The MVP needed to be small, reproducible, and easy to demo end to end.

Kafka would have added brokers, topics, partitions, storage, networking, and monitoring before the basic CPEmon flow was proven.

For the MVP, MySQL queue tables were good enough to demonstrate durable buffering and background processing.

## Q4: Why introduce Kafka now?

The project has moved from MVP demonstration into cloud platform upgrade.

Kafka gives a better event-driven architecture story:

- durable event log
- producer/consumer decoupling
- replay potential
- partitioning and scaling path
- clearer topic ownership and retention model
- stronger alignment with platform and data-engineering patterns

## Q5: Why choose a Helm chart based Kafka deployment first?

Because it fits the Step 1 learning path.

The project already uses Helm, and the first Kafka task should be small enough to render, install, validate, and explain.

A Helm chart based install lets me focus on:

- Kafka namespace
- chart values
- bootstrap service
- topic plan
- manual produce/consume validation
- operational documentation

without immediately adding operator-specific or managed-service complexity.

## Q6: Why not Strimzi first?

Strimzi is a strong future option, but it introduces an operator and Kafka-specific CRDs.

That is valuable when lifecycle management becomes the priority:

- Kafka cluster reconciliation
- KafkaTopic resources
- KafkaUser resources
- certificate and listener management
- upgrade workflows

For Step 1, the project first needs to prove the simpler Kafka platform contract.

## Q7: Why not Amazon MSK first?

MSK is a strong production direction, but it adds cloud-specific decisions early:

- VPC and subnet placement
- security groups
- endpoint access
- cost
- IAM and authentication choices
- Terraform module scope

Those decisions are real, but they are better handled after the project has stable topic names, bootstrap configuration, and application integration boundaries.

## Q8: What is the key abstraction that keeps future migration possible?

The key abstraction is the bootstrap and topic configuration contract.

The application should depend on configuration such as:

```text
KAFKA_BOOTSTRAP_SERVERS
KAFKA_TOPIC_DEVICE_HEARTBEAT
KAFKA_TOPIC_WAN_STATUS
KAFKA_TOPIC_DEADLETTER
```

If those values are stable, the broker implementation can move from Helm chart Kafka to Strimzi or MSK with less application impact.

## Q9: What does CCPU-69 prove?

It proves the deployment decision is intentional and scoped.

It proves why the project starts with Helm chart Kafka, why Strimzi and MSK are deferred, and how this decision fits the earlier MVP no-Kafka decision.

It does not prove live Kafka installation or application event publishing.

## Q10: What is the validation boundary for CCPU-69?

CCPU-69 is a decision and documentation task.

It validates:

- ADR exists
- tradeoffs are documented
- knowledge notes exist
- interview questions exist

It does not validate:

- broker pods running
- topics created
- produce/consume success
- application code publishing Kafka events

Those belong to later subtasks.

## Q11: How would you explain this in 60 seconds?

The original CPEmon MVP deliberately avoided Kafka because the first goal was an end-to-end demo, not a distributed streaming platform. It used MySQL queue tables as a simple durable buffer. In the cloud-platform upgrade, Kafka becomes the event-buffering layer, but I introduced it in phases. For Step 1, I chose a Helm chart based Kafka deployment because the project already uses Helm and I wanted to prove the namespace, install workflow, bootstrap config, topic plan, and manual validation before changing application code. Strimzi is a good future option for Kubernetes-native Kafka lifecycle management, and MSK is a good production direction for managed broker operations. The stable boundary is `KAFKA_BOOTSTRAP_SERVERS` and topic configuration, so the application can move between broker deployment models later.

## Q12: What is the main tradeoff in the decision?

The tradeoff is speed and learning clarity versus production-grade lifecycle management.

A Helm chart based deployment is easier to start with and fits the current project. Strimzi or MSK may be better for later production hardening, but choosing them immediately would expand the first Kafka story too much.

## Q13: What did CCPU-70 add?

`CCPU-70` added the Kafka Helm installation workflow.

The key files are:

```text
k8s/addons/kafka/values.yaml
ops/runbooks/kafka-platform-helm.md
scripts/verify-kafka-helm-workflow.ps1
Makefile
```

It also updated the Kafka knowledge notes with the install boundary.

## Q14: Why keep the Kafka values small?

Because Story 8 is introducing the platform boundary first.

The Step 1 values use one KRaft controller, an internal `ClusterIP` service, no external access, and persistent storage. That is enough to prove the first install and bootstrap path without pretending to be a production Kafka design.

Production concerns such as multi-broker sizing, TLS, SASL, external listeners, metrics, Strimzi, or MSK are deferred until the platform contract is clear.

## Q15: What is the expected internal bootstrap server?

For release `kafka` in namespace `kafka`, the expected internal bootstrap address is:

```text
kafka.kafka.svc.cluster.local:9092
```

Later application integration should receive it through:

```text
KAFKA_BOOTSTRAP_SERVERS
```

not through a hardcoded value in Go code.

## Q16: What are the key Makefile targets?

The Kafka platform targets are:

```text
make kafka-chart-show
make kafka-template
make kafka
make kafka-check
make kafka-validate
make kafka-helm-workflow-check
```

`kafka-template` proves chart rendering. `kafka` performs the live install or upgrade. `kafka-check` validates the release and Kubernetes resources. `kafka-helm-workflow-check` validates the repository workflow even when Helm is not installed locally.

## Q17: What was the validation boundary for CCPU-70?

The repository workflow validation passed, but live Helm validation was blocked because `helm` was not available on PATH in the local shell.

That means CCPU-70 can claim:

- values file exists
- runbook exists
- Makefile targets exist
- documentation is connected
- workflow check script passes

It cannot claim:

- chart render success
- live Helm install success
- Kafka pod readiness
- real broker connectivity

That honesty is important in platform work because a documented command is not the same as a running cluster.

## Q18: How would you explain CCPU-70 in an interview?

I added the first Kafka Helm workflow rather than jumping straight to application code. The values file defines a small internal Kafka deployment, the Makefile gives repeatable render/install/check targets, and the runbook explains validation, troubleshooting, rollback, and the bootstrap contract. Since Helm was not available in the local shell, I documented that as the validation boundary and added a repository-level workflow check rather than falsely claiming a live install.

## Q19: What did CCPU-71 add?

`CCPU-71` made the Kafka namespace boundary explicit and verifiable.

The key files are:

```text
k8s/base/namespaces.yaml
ops/runbooks/kafka-namespace.md
scripts/verify-kafka-namespace.ps1
Makefile
```

The namespace already existed in the base namespace manifest, and this subtask documented why it exists and added a focused validation path.

## Q20: Why does Kafka get its own namespace?

Kafka is a platform data-streaming dependency, not a CPEmon application Deployment.

Putting it in its own namespace gives a cleaner boundary for:

- Helm release ownership
- storage and PVC troubleshooting
- NetworkPolicy
- RBAC
- monitoring selectors
- future Strimzi migration

The application namespace can stay focused on CPEmon workloads while the `kafka` namespace owns broker resources.

## Q21: What labels identify the Kafka namespace?

The namespace uses:

```yaml
app.kubernetes.io/part-of: cpemon-mvp
app.kubernetes.io/name: kafka
cpemon.io/layer: data-streaming
cpemon.io/managed-by: gitops-ready-manifest
```

The most important project-specific label is:

```text
cpemon.io/layer=data-streaming
```

## Q22: What is the validation boundary for CCPU-71?

Local validation checks the Git manifest:

```powershell
powershell -ExecutionPolicy Bypass -File scripts/verify-kafka-namespace.ps1
```

Live validation requires a cluster:

```powershell
kubectl apply -f k8s/base/namespaces.yaml
kubectl get ns kafka --show-labels
```

So the subtask can prove the namespace contract exists in Git even when a live cluster is not available.

## Q23: What did CCPU-72 add?

`CCPU-72` defined the first CPEmon Kafka topics in the Kafka Helm values.

The key files are:

```text
k8s/addons/kafka/values.yaml
ops/runbooks/kafka-topics.md
scripts/verify-kafka-topics.ps1
Makefile
```

## Q24: What are the initial topics?

The initial topics are:

```text
cpemon.device.heartbeat.v1
cpemon.wan.status.v1
cpemon.deadletter.v1
```

`device.heartbeat` is for heartbeat events. `wan.status` is for connectivity/status events. `deadletter` is for failed or unprocessable events that need debugging or replay decisions.

## Q25: What Step 1 topic settings did you choose?

For Step 1:

```text
partitions=1
replicationFactor=1
retention.ms=604800000
```

That is seven days of retention.

This is intentionally small because the current Kafka deployment is a learning-path cluster, not a production multi-broker cluster.

## Q26: Why define topics before producer code?

Topic names are part of the platform contract.

If I define topics first, later application code can read topic names from configuration instead of inventing hardcoded strings. It also makes event ownership, dead-letter behavior, and migration decisions easier to review.

## Q27: What is the validation boundary for CCPU-72?

Local validation checks the values file and docs:

```powershell
powershell -ExecutionPolicy Bypass -File scripts/verify-kafka-topics.ps1
```

Live validation requires Kafka to be installed and ready:

```powershell
kubectl exec -n kafka statefulset/kafka-controller -- kafka-topics.sh `
  --bootstrap-server kafka.kafka.svc.cluster.local:9092 `
  --list
```

So CCPU-72 proves the topic contract in Git, while live broker topic existence belongs to cluster validation.

## Q28: What did CCPU-73 add?

`CCPU-73` added the application-facing Kafka configuration boundary.

The key files are:

```text
deploy/helm/cpemon/values.yaml
deploy/helm/cpemon/templates/configmap.yaml
deploy/helm/cpemon/values.schema.json
k8s/app/cpemon-app-config.yaml
ops/runbooks/kafka-bootstrap-config.md
scripts/verify-kafka-config-boundary.ps1
Makefile
```

## Q29: What Kafka config keys did you add?

The config keys are:

```text
KAFKA_BOOTSTRAP_SERVERS
KAFKA_TOPIC_DEVICE_HEARTBEAT
KAFKA_TOPIC_WAN_STATUS
KAFKA_TOPIC_DEADLETTER
```

The Step 1 bootstrap value is:

```text
kafka.kafka.svc.cluster.local:9092
```

## Q30: Why put these values in ConfigMap-style app config?

The bootstrap DNS name and topic names are non-secret configuration.

They should be reviewable and environment-specific, but they are not credentials. Future TLS keys, SASL passwords, tokens, or MSK IAM-related secret material should use Secret references or External Secrets Operator.

## Q31: Why expose topic names as config instead of hardcoding them?

Topic names are platform contracts.

If application code reads topic names from config, the platform can rename, version, or migrate topics through deployment configuration. That is much easier to operate than recompiling code for every topic change.

## Q32: How does this help a future Strimzi or MSK migration?

The app should depend on:

```text
KAFKA_BOOTSTRAP_SERVERS
```

not on Bitnami chart internals, pod names, or a specific service implementation.

Later, the value can change from:

```text
kafka.kafka.svc.cluster.local:9092
```

to a Strimzi bootstrap service or MSK broker endpoint while keeping the application contract stable.

## Q33: What is the validation boundary for CCPU-73?

Local validation checks the repository contract:

```powershell
powershell -ExecutionPolicy Bypass -File scripts/verify-kafka-config-boundary.ps1
```

Live validation requires Helm rendering or an applied ConfigMap:

```powershell
make helm-cpemon-template
kubectl get configmap cpemon-app-config -n cpemon -o yaml
```

Because Helm is still unavailable in the local shell, this subtask proves the committed config boundary but does not claim live render/apply validation.

## Q34: What did CCPU-74 add?

`CCPU-74` added the manual Kafka produce/consume validation runbook.

The key files are:

```text
ops/runbooks/kafka-produce-consume-validation.md
scripts/verify-kafka-produce-consume-runbook.ps1
Makefile
```

## Q35: What does manual produce/consume prove?

It proves platform-level Kafka connectivity:

- the broker is reachable
- the topic exists
- a producer can write to the topic
- a consumer can read from the topic

It does not prove CPEmon application producer code, because no application producer has been implemented in this story.

## Q36: What test message does the runbook use?

The runbook uses:

```json
{"source":"manual-kafka-validation","serialNumber":"TEST-CPE-0001","status":"online","ts":"2026-06-21T00:00:00Z"}
```

That message is deliberately simple. It is a platform connectivity probe, not the final event schema.

## Q37: What commands matter most?

Producer:

```powershell
kafka-console-producer.sh --bootstrap-server kafka.kafka.svc.cluster.local:9092 --topic cpemon.device.heartbeat.v1
```

Consumer:

```powershell
kafka-console-consumer.sh --bootstrap-server kafka.kafka.svc.cluster.local:9092 --topic cpemon.device.heartbeat.v1 --from-beginning --max-messages 1
```

## Q38: What is the validation boundary for CCPU-74?

Local validation checks the runbook:

```powershell
powershell -ExecutionPolicy Bypass -File scripts/verify-kafka-produce-consume-runbook.ps1
```

Live validation requires a running Kafka release and real cluster access. Without those, I can document the exact commands but cannot honestly claim a successful produce/consume test.

## Q39: What did CCPU-75 add?

`CCPU-75` added the Kafka topic naming convention.

The key files are:

```text
docs/knowledge/kafka-topic-naming-convention.md
scripts/verify-kafka-topic-naming.ps1
Makefile
```

## Q40: What topic naming pattern did you choose?

The pattern is:

```text
cpemon.<domain>.<event-family>.v<major>
```

Examples:

```text
cpemon.device.heartbeat.v1
cpemon.wan.status.v1
cpemon.deadletter.v1
```

## Q41: Why include a version suffix?

The version suffix marks major compatibility.

If a future event shape changes incompatibly, the project can introduce a `v2` topic rather than breaking existing consumers. Optional additive fields usually do not require a new major topic version.

## Q42: Why not include environment names in topic names?

Environment is a deployment concern, not part of the logical event contract.

The same topic name can exist in dev and prod clusters:

```text
cpemon.device.heartbeat.v1
```

The separation comes from cluster/account/namespace/Helm values, not from renaming the event.

## Q43: Why not name the topic after the producer service?

Producer services can change.

The topic should represent the event domain and purpose, not the current implementation. `cpemon.device.heartbeat.v1` is more stable than `cpemon-api-heartbeat` because another service could produce heartbeat events later.

## Q44: What is the dead-letter naming rule?

Story 8 starts with:

```text
cpemon.deadletter.v1
```

That is a shared dead-letter topic for Step 1. Later, if failures need stronger ownership boundaries, it can evolve into domain-specific dead-letter topics such as:

```text
cpemon.device.deadletter.v1
cpemon.wan.deadletter.v1
```

## Q45: How would you summarize the naming decision?

I treated Kafka topic names as platform contracts. The pattern `cpemon.<domain>.<event-family>.v<major>` keeps names business-oriented, versioned, and independent of environment or broker implementation. That makes topics easier to document, monitor, migrate, and explain in an interview.

## Q46: What did CCPU-159 add?

`CCPU-159` added the Kafka platform architecture and migration decision.

The key files are:

```text
ADR/cloud-platform-upgrade-kafka-platform-architecture.md
docs/knowledge/kafka-platform-architecture-migration.md
scripts/verify-kafka-architecture-docs.ps1
Makefile
```

## Q47: Where does Kafka sit in the CPEmon architecture?

Kafka sits between ingestion and downstream processing.

The future target is:

```text
acs-ingest / cpemon-api
        |
        v
Kafka topics
        |
        v
cpemon-writer / consumers
        |
        v
MySQL business tables
```

Kafka replaces the queue role, not the business database role.

## Q48: Why does Story 8 not immediately replace the MySQL queue?

Because platform readiness and application behavior should be validated separately.

Replacing the queue immediately would mix Kafka install risk, topic risk, producer-code risk, consumer-code risk, and data consistency risk. Story 8 keeps the current MySQL queue path as the baseline while preparing and validating the Kafka platform contract.

## Q49: What is the migration sequence?

The sequence is:

```text
1. Keep current MySQL queue path as baseline.
2. Introduce Kafka namespace and Helm workflow.
3. Define topics and bootstrap config.
4. Validate manual produce/consume.
5. Add application producers and consumers later.
6. Retire or reduce MySQL queue behavior after Kafka path is proven.
```

## Q50: How would you explain CCPU-159 in an interview?

I introduced Kafka as a platform boundary before changing application code. That let me prove the Kafka namespace, Helm workflow, topics, bootstrap config, and manual validation path separately from producer and consumer logic. The current MySQL queue remains the running baseline until the Kafka path is proven. That is safer than a big-bang rewrite because each risk has its own validation step.

## Q51: What did CCPU-160 add?

`CCPU-160` added the top-level Kafka validation and observability runbook.

The key files are:

```text
ops/runbooks/kafka-validation-observability.md
scripts/verify-kafka-validation-observability.ps1
Makefile
```

## Q52: What is the difference between repository validation and live validation?

Repository validation proves that Git contains the expected files, values, docs, scripts, topic names, and config keys.

Live validation proves that a real cluster can run Kafka: namespace exists, Helm release is deployed, pods are Ready, PVCs are Bound, topics exist, produce/consume works, and logs/metrics can be inspected.

## Q53: What Kafka observability signals matter?

Important signals include:

- broker pod readiness
- restarts
- PVC health
- topic produce/consume traffic
- consumer group lag
- dead-letter topic traffic
- under-replicated partitions in multi-broker mode
- offline partitions

## Q54: Why not claim Prometheus Kafka metrics now?

Because the Step 1 Kafka values keep metrics disabled while the platform contract is introduced.

Prometheus Kafka metrics should only be claimed after an exporter is enabled, ServiceMonitor or scrape config is installed, and Prometheus confirms the Kafka target is being scraped.

## Q55: How would you debug Kafka if produce/consume fails?

I would check in layers:

```text
namespace -> Helm release -> pods -> service -> PVC -> topics -> broker logs -> producer command -> consumer command
```

That avoids jumping straight to application code when the platform itself may not be ready.

## STAR Story

Situation:

CPEmon started as an MVP that used MySQL queue tables instead of Kafka so the first demo could stay small and complete.

Task:

In the cloud-platform upgrade, I needed to introduce Kafka as a more realistic event buffer without mixing platform setup, managed service design, and application integration into one large task.

Action:

I chose a Helm chart based Kafka deployment for Step 1, documented why it fits the current EKS and Helm learning path, added a small Kafka values file, Makefile targets, a Helm runbook, a Kafka namespace runbook, initial topic definitions, Kafka bootstrap configuration keys, a manual produce/consume validation runbook, a topic naming convention, Kafka architecture migration docs, validation and observability notes, and workflow validation scripts. I explicitly deferred Strimzi and MSK until lifecycle automation or managed production operations become the main concern.

Result:

The project now has a clear Kafka migration sequence: prove the platform boundary first, then add topics and validation, then integrate application producers and consumers, and later consider Strimzi or MSK behind the same bootstrap/topic contract.
