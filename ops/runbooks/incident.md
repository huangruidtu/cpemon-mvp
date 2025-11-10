# Incident Runbook (MVP)

## Symptoms
- Queue backlog surge
- ES disk full
- MySQL connections spike

## Quick Checks
- Grafana: queue length, writer lag, success rate
- Kibana: errors around ingest/writer
- MySQL: processlist, slow queries

## First Response
- Scale writer (HPA/manual), throttle ingest
- Purge old ES indices per ILM
- Increase MySQL max connections temporarily; investigate source
