# Changelog
All notable changes to this project will be documented in this file.

## [day1-done] - 2025-11-10
### Added
- Ingress-NGINX as **Deployment + Service(type=LoadBalancer via MetalLB)**, scheduled **worker-only**.
- MetalLB L2: IPAddressPool `10.0.0.200-10.0.0.210` + L2Advertisement.
- PDBs: `cpemon-api-pdb`, `acs-ingest-pdb` (`minAvailable: 1`) to protect voluntary disruptions.
- `scripts/smoke.sh` for Day-1 DoD (404 default backend, 200 on `/echo`).
- Echo sample (`k8s/samples/echo/*`) for ingress routing validation.

### Changed
- Strategy switched from **DaemonSet + hostNetwork** to **Deployment + LoadBalancer** for mainstream production parity and simpler HA.

### Fixed
- Resolved Helm ownership conflicts when switching strategies.

### Notes
- Day-1 DoD: `http(s)://api.local` → 404 default backend; `https://api.local/echo` → 200 OK.
- PDB `Allowed disruptions` will become `1` after replicas scale to 2 on Day-3.
