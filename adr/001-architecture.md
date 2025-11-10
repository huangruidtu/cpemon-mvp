# ADR-001: MVP Architecture

- Ingress: NGINX as DaemonSet + hostNetwork on worker (10.0.0.101), host-based routing.
- Control-plane tainted; only HA “backup” replicas tolerate master.
- Queue: MySQL table (no Kafka yet) for simplicity and easy demo.
- Observability: kube-prometheus-stack (Prom+Grafana), ELK single node (7–14 days retention).
- Backups: Velero to S3 (Day 7).
