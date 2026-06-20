# EKS StorageClass Verification Runbook

## Purpose

Use this runbook to verify the default StorageClass for the CPEmon dev EKS cluster.

This runbook belongs to `CCPU-47`.

## Current Boundary

The EKS cluster has not been applied yet, so live `kubectl` checks cannot run now.

This task prepares:

- StorageClass validation commands
- a candidate gp3 default StorageClass manifest
- the decision path for EBS CSI driver dependency

## Key Concepts

Storage chain:

```text
Pod -> PersistentVolumeClaim -> StorageClass -> CSI driver -> AWS EBS volume -> PersistentVolume -> mounted volume
```

Important distinction:

- A `StorageClass` is a template/policy for dynamic volume provisioning.
- A `PersistentVolumeClaim` is a workload's request for storage.
- A `PersistentVolume` is the actual Kubernetes storage object bound to the claim.
- The Amazon EBS CSI driver is the component that calls AWS APIs to create EBS volumes.

## Verify Existing StorageClasses

```powershell
make storage-check
```

Direct commands:

```powershell
kubectl get storageclass
kubectl get storageclass -o custom-columns=NAME:.metadata.name,DEFAULT:.metadata.annotations.storageclass\.kubernetes\.io/is-default-class,PROVISIONER:.provisioner,VOLUME_BINDING:.volumeBindingMode,ALLOW_EXPANSION:.allowVolumeExpansion
kubectl describe storageclass
```

Expected healthy direction for this project:

```text
gp3 default StorageClass
provisioner: ebs.csi.aws.com
volumeBindingMode: WaitForFirstConsumer
allowVolumeExpansion: true
encrypted: true
```

## Why gp3

`gp3` is the modern general-purpose EBS volume type. It is normally preferred over `gp2` for new EKS workloads because performance settings are more explicit and it is the current default direction for many AWS storage designs.

## Candidate Manifest

Prepared manifest:

```text
k8s/addons/storage/gp3-storageclass.yaml
```

Dry-run:

```powershell
make storage-gp3-plan
```

Apply after EBS CSI prerequisites exist:

```powershell
make storage-gp3-apply
```

## EBS CSI Driver Prerequisite

For standard EKS node groups, the provisioner should be:

```text
ebs.csi.aws.com
```

The EBS CSI driver needs AWS permissions. AWS recommends installing it as an EKS add-on and giving it IAM permission through EKS Pod Identity or IRSA.

If the EBS CSI driver is missing, PVC events may show errors such as:

```text
failed to provision volume with StorageClass
could not create volume in EC2: UnauthorizedOperation
```

## Troubleshooting

If no default StorageClass exists:

1. Confirm whether EBS CSI driver is installed.
2. Confirm whether a gp3 StorageClass should be created.
3. Confirm no old `gp2` class should remain default.
4. Apply `gp3-storageclass.yaml` only after the driver and IAM permissions exist.

If PVC stays Pending:

```powershell
kubectl describe pvc <name> -n <namespace>
kubectl get events -n <namespace> --sort-by=.lastTimestamp
kubectl get pods -n <namespace>
```

Remember that `WaitForFirstConsumer` intentionally delays EBS volume creation until a pod is scheduled. This is useful because EBS volumes are Availability-Zone scoped and should be created in the same AZ as the consuming pod.
