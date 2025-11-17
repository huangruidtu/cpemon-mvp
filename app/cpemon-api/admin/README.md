# CPEmon Admin Page Design

This document describes the initial design of the `/admin` page provided by `cpemon-api`.

## 1. Goal

Provide a single-page "admin cockpit" to troubleshoot a single CPE:

- Search by SN.
- Show current CPE status (`cpe_status`).
- Show last N entries from the history table (`cpe_status_history`).
- Reserve space for small metrics charts (from Prometheus) and a Kibana deep link.

Authentication (Basic Auth / token) and IP whitelist will be implemented in later tasks.

---

## 2. HTTP contract

- **URL**: `GET /admin`
- **Query parameters**:
  - `sn`: string (CPE serial number), optional.
- **Behavior**:
  - Without `sn`:
    - Render the admin page with a search box and an empty state.
  - With `sn`:
    - Render the page with:
      - Current CPE status (if found).
      - Recent history records (up to N items).
      - Right-side panel for metrics mini charts and a Kibana deep link.

Example:

```http
GET /admin?sn=CPE123

