# CPE Monitoring MVP (cpemon-mvp)

A one-week SRE/DevOps demo project: ACS → Webhook → MySQL queue → Writer → Status/History,
with Prom+Grafana, ELK, and Velero.

## Topology
- Master: 10.0.0.100 (control-plane; tainted)
- Worker: 10.0.0.101 (ingress, workloads)
- VM3:    10.0.0.13 (GenieACS, CPE simulator)

## Day 1 Status
- Kubernetes Ready; Calico v3.27.3 installed (podCIDR 192.168.0.0/16)
- Ingress-NGINX: DaemonSet + hostNetwork(80/443) on worker
- Namespaces + PDB presets

## Quick commands
```bash
kubectl get nodes -o wide
kubectl -n ingress-nginx get pods -o wide
curl -I -k https://api.local  # expect 404

