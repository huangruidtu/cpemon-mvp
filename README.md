# cpemon-mvp

**Day 1 — Cluster base & ingress ready**

- K8s: master=10.0.0.100, worker=10.0.0.101, VM3=10.0.0.13
- Ingress-NGINX: **Deployment + LoadBalancer (MetalLB)**, worker-only
- MetalLB IP pool: 10.0.0.200–10.0.0.210 (L2Advertisement enabled)
- Hostnames → LB IP: `api.local`, `admin.local`, `grafana.local`, `kibana.local`

## Quick smoke
    ./scripts/smoke.sh
    # expect: http(s)://api.local -> 404
    #         https://api.local/echo -> 200

## Key manifests
- k8s/ingress-nginx/values.yaml
- k8s/pdb/ — PDBs for `cpemon-api`, `acs-ingest` (minAvailable=1)
- k8s/samples/echo/ — echo Deployment/Service/Ingress (for 200 OK)
