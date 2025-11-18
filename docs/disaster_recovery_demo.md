## Disaster Recovery Demo (Velero)

This project includes a one-command disaster recovery demo based on **Velero**.  
The demo shows how we:

1. Take a backup of the `cpemon` namespace.
2. Simulate a failure by deleting the `cpemon-api` components.
3. Restore the application from the Velero backup.
4. Verify that the API is healthy again.

### Prerequisites

- Velero installed and configured in the cluster (server version `v1.17.x` or compatible).
- Velero running in namespace: `backup`.
- A working backup storage location pointing to S3 (e.g. bucket `cpemon-velero`).
- The CPEmon stack deployed in namespace: `cpemon`.
- The smoke test script is available and executable:

  ```bash
  chmod +x scripts/smoke.sh scripts/backup_restore.sh

