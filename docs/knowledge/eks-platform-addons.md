# EKS Platform Add-ons

## Why This Story Exists

`CCPU-5` builds the first Kubernetes platform layer on top of the EKS foundation from `CCPU-4`.

The earlier story created Terraform definitions for the AWS side: VPC, subnets, EKS control plane, managed node group, and access entries. This story moves one layer up:

```text
AWS infrastructure -> EKS cluster -> Kubernetes platform add-ons -> CPEmon workloads
```

This page is the learning home for the add-on story. Each subtask should add to it, so the final result is useful for review and interviews.

Current important boundary:

```text
The EKS cluster has not been applied yet.
The manifests and commands are prepared now.
Live kubectl validation happens after the cluster exists.
```

## What Platform Add-ons Mean

Platform add-ons are the shared capabilities that application teams expect before deploying their services.

For this project, the platform layer includes:

- namespaces for separation
- metrics-server for Kubernetes resource metrics
- AWS Load Balancer Controller for ALB/NLB integration
- StorageClass verification for persistent volume behavior
- a disposable echo service for platform smoke testing
- external access verification
- baseline NetworkPolicy thinking
- repeatable Makefile checks
- runbooks for common failures

This is different from deploying the CPEmon application itself. The platform layer proves the cluster has the basic operating surface ready.

## CCPU-46: Platform Namespaces

Namespaces are the first EKS platform add-on task because nearly everything else needs a place to live.

The namespace manifest is:

```text
k8s/base/namespaces.yaml
```

The standard EKS platform namespaces are:

| Namespace | Purpose |
| --- | --- |
| `cpemon` | CPEmon application workloads such as API, writer, ingest, MySQL, and app services. |
| `platform` | Platform smoke tests and shared platform validation resources, such as the echo test service. |
| `monitoring` | Observability stack resources such as Prometheus, Grafana dashboards, alerts, and ServiceMonitors. |
| `argocd` | Future GitOps controller namespace. Even if Argo CD is not installed yet, naming it now reserves the platform boundary. |
| `kafka` | Future streaming/messaging layer. This project previously deferred Kafka for MVP, but the migration roadmap expects it later. |
| `security` | Security tooling, policy controllers, scanners, and admission controls. |
| `cost` | FinOps/cost visibility tooling. This keeps cost observability separate from application monitoring. |
| `backup` | Existing backup/restore jobs from the MVP. Kept for compatibility with current manifests. |
| `ingress-nginx` | Existing lab ingress namespace. Kept for compatibility, but EKS external access should prefer AWS Load Balancer Controller. |

## Why Not Use `kubectl create namespace`

This command works:

```powershell
kubectl create namespace cpemon
```

But it is not the best fit for this migration.

The project uses committed YAML manifests instead:

```powershell
kubectl apply -f k8s/base/namespaces.yaml
```

Reasons:

- The namespace list becomes reviewable in Git.
- Labels are versioned with the namespace.
- The same file can be applied repeatedly.
- Future GitOps tools such as Argo CD can own the same manifest.
- Interview explanation is stronger because the platform boundary is visible as code.

## Namespace Labels

Each namespace has standard labels:

```yaml
app.kubernetes.io/part-of: cpemon-mvp
app.kubernetes.io/name: <namespace>
cpemon.io/layer: <platform-layer>
cpemon.io/managed-by: gitops-ready-manifest
```

The `app.kubernetes.io/*` labels follow common Kubernetes labeling conventions.

The `cpemon.io/*` labels are project-specific. They help teach and inspect the platform model:

- `cpemon.io/layer` explains why the namespace exists.
- `cpemon.io/managed-by` records that the namespace is meant to be managed from Git, not by one-off console or CLI actions.

Labels are not just decoration. Later, labels can help with:

- cost allocation
- policy targeting
- inventory queries
- GitOps grouping
- audit and ownership review

## Apply and Validate

After the EKS cluster exists and kubeconfig is configured:

```powershell
make ns
make ns-check
```

Equivalent direct commands:

```powershell
kubectl apply -f k8s/base/namespaces.yaml
kubectl get ns
kubectl get ns -L cpemon.io/layer,cpemon.io/managed-by
```

Expected result:

```text
cpemon
platform
monitoring
argocd
kafka
security
cost
backup
ingress-nginx
```

If `kubectl get ns` fails, do not debug namespace YAML first. Start by checking cluster access:

```powershell
kubectl config current-context
kubectl cluster-info
aws sts get-caller-identity --profile cpemon-terraform
```

## How This Helps Later Tasks

The namespace step unlocks later CCPU-5 tasks:

- metrics-server can be installed and checked from `kube-system`, while monitoring docs explain its relationship to `monitoring`.
- AWS Load Balancer Controller can be installed in `kube-system`, while app ingress resources can live in `platform` or `cpemon`.
- echo service can live in `platform` without mixing with real CPEmon workloads.
- NetworkPolicy work can start with namespace boundaries.
- Makefile checks can target stable namespace names.

## CCPU-44: metrics-server With Helm

metrics-server provides the Kubernetes resource metrics API.

It powers commands such as:

```powershell
kubectl top nodes
kubectl top pods -A
```

It is also commonly used by autoscaling features such as Horizontal Pod Autoscaler.

Important interview distinction:

```text
metrics-server is not Prometheus.
```

metrics-server gives recent CPU/memory resource metrics to the Kubernetes API. It is meant for autoscaling and quick operational checks. It is not a historical monitoring database, alerting system, dashboard backend, or long-term metrics store.

AWS documents that metrics-server is not deployed by default in EKS clusters. AWS also notes that the metrics are for point-in-time analysis and are not a replacement for a monitoring solution. That is why CPEmon should still keep Prometheus/Grafana style monitoring separate from metrics-server.

For this project, we chose Helm instead of applying the upstream install manifest directly.

Values file:

```text
k8s/addons/metrics-server/values.yaml
```

Install path:

```powershell
helm repo add metrics-server https://kubernetes-sigs.github.io/metrics-server/
helm repo update
helm upgrade --install metrics-server metrics-server/metrics-server `
  --namespace kube-system `
  --version 3.13.1 `
  --values k8s/addons/metrics-server/values.yaml
```

Makefile path:

```powershell
make helm-repos
make metrics-server
make metrics-server-check
```

Validation:

```powershell
kubectl get deployment -n kube-system metrics-server
kubectl top nodes
kubectl top pods -A
```

Current boundary:

```text
The Helm values are committed.
The cluster does not exist yet.
Helm, kubectl, and live metrics validation must happen after EKS apply.
```

## CCPU-45: AWS Load Balancer Controller With Helm

AWS Load Balancer Controller is the EKS-native controller for managing AWS Elastic Load Balancing resources from Kubernetes.

It watches Kubernetes resources and creates AWS resources:

| Kubernetes resource | AWS resource |
| --- | --- |
| `Ingress` | Application Load Balancer |
| `Service` type `LoadBalancer` | Network Load Balancer |
| Gateway API resources in newer versions | Application Load Balancer |

This is why it is a better EKS default than copying the old lab path of `ingress-nginx` plus MetalLB.

The important point is not that ingress-nginx is useless. ingress-nginx can still be valid in many clusters. The point is that on EKS, AWS Load Balancer Controller integrates directly with ALB/NLB, subnet tags, target groups, security groups, and AWS load balancer lifecycle.

AWS also documents that the legacy AWS cloud provider path can still provision load balancers, but it creates Classic Load Balancers and should be avoided in favor of AWS Load Balancer Controller.

Values file:

```text
k8s/addons/aws-load-balancer-controller/values.yaml
```

Install path:

```powershell
helm repo add eks https://aws.github.io/eks-charts
helm repo update
helm upgrade --install aws-load-balancer-controller eks/aws-load-balancer-controller `
  --namespace kube-system `
  --version 1.14.0 `
  --values k8s/addons/aws-load-balancer-controller/values.yaml `
  --set clusterName=cpemon-dev `
  --set region=eu-north-1 `
  --set vpcId=<vpc-id> `
  --set serviceAccount.annotations."eks\.amazonaws\.com/role-arn"=<aws-lbc-role-arn>
```

Makefile path:

```powershell
make helm-repos
make aws-lbc EKS_VPC_ID=<vpc-id> AWS_LBC_ROLE_ARN=<aws-lbc-role-arn>
make aws-lbc-check
```

Validation:

```powershell
kubectl get deployment -n kube-system aws-load-balancer-controller
kubectl logs -n kube-system deploy/aws-load-balancer-controller --tail=80
```

The controller needs AWS IAM permissions. In EKS, the clean pattern is to bind an IAM role to the Kubernetes service account with IRSA or EKS Pod Identity.

For this project, the service account name is:

```text
aws-load-balancer-controller
```

The namespace is:

```text
kube-system
```

The IAM role still needs to be created after the cluster OIDC provider exists or as part of a Terraform follow-up. The Helm values are prepared now, but the live install needs:

- cluster name
- region
- VPC ID
- AWS Load Balancer Controller IAM role ARN
- matching service account annotation
- public/private subnets tagged for EKS load balancer discovery

## Helm vs kubectl Apply

For add-ons, Helm gives a stronger platform-management story than raw manifest URLs:

- chart repository and chart version are explicit
- environment-specific values live in Git
- upgrades can be repeated with `helm upgrade`
- rollbacks and release history are possible
- the install method matches how many EKS teams manage add-ons

Raw `kubectl apply -f <url>` can be useful for a quick test, but it is harder to review, pin, tune, and upgrade as a platform asset.

## CCPU-47: Verify Default StorageClass

StorageClass verification answers this question:

```text
If a CPEmon workload creates a PersistentVolumeClaim without naming a storage class, what kind of storage will Kubernetes create?
```

That question matters for stateful workloads such as MySQL, future Kafka, backup jobs, and any component that needs data to survive pod replacement.

## Storage Mental Model

The storage flow is:

```text
Pod
  -> PersistentVolumeClaim
  -> StorageClass
  -> CSI driver
  -> AWS EBS volume
  -> PersistentVolume
  -> mounted filesystem inside the pod
```

Definitions:

| Term | Meaning |
| --- | --- |
| `StorageClass` | A policy/template for dynamic storage provisioning. |
| `PersistentVolumeClaim` | A workload request for storage. |
| `PersistentVolume` | The Kubernetes object representing actual storage bound to a claim. |
| CSI driver | The plugin that talks to a storage provider such as AWS EBS. |
| EBS volume | The AWS block storage volume created for the workload. |

## EKS and Amazon EBS CSI

In standard EKS clusters, persistent EBS volumes should use the Amazon EBS CSI driver.

The standard EBS CSI provisioner is:

```text
ebs.csi.aws.com
```

AWS recommends installing the Amazon EBS CSI driver as an EKS add-on to reduce operational work. The driver still needs AWS IAM permissions because it creates and manages EBS volumes on behalf of Kubernetes.

For EKS Auto Mode, AWS documents a different provisioner:

```text
ebs.csi.eks.amazonaws.com
```

This project is not using EKS Auto Mode, so the prepared StorageClass uses:

```text
ebs.csi.aws.com
```

## Why gp3

The prepared StorageClass is `gp3`:

```text
k8s/addons/storage/gp3-storageclass.yaml
```

`gp3` is the modern EBS general-purpose volume type. For this dev platform, the intended default is:

```yaml
provisioner: ebs.csi.aws.com
parameters:
  type: gp3
  encrypted: "true"
allowVolumeExpansion: true
volumeBindingMode: WaitForFirstConsumer
```

`WaitForFirstConsumer` is especially important on EKS because EBS volumes are Availability-Zone scoped. Kubernetes should wait until it knows where the consuming pod will run before creating the EBS volume.

## Verification Commands

After the EKS cluster exists:

```powershell
make storage-check
```

Direct commands:

```powershell
kubectl get storageclass
kubectl describe storageclass
kubectl get storageclass -o custom-columns=NAME:.metadata.name,DEFAULT:.metadata.annotations.storageclass\.kubernetes\.io/is-default-class,PROVISIONER:.provisioner,VOLUME_BINDING:.volumeBindingMode,ALLOW_EXPANSION:.allowVolumeExpansion
```

Expected direction:

```text
gp3 should be the default StorageClass.
provisioner should be ebs.csi.aws.com.
volumeBindingMode should be WaitForFirstConsumer.
allowVolumeExpansion should be true.
```

## Prepared But Not Applied

The candidate manifest is prepared now:

```powershell
make storage-gp3-plan
make storage-gp3-apply
```

But `storage-gp3-apply` should only run after:

- EKS cluster exists.
- EBS CSI driver is installed.
- EBS CSI controller has IAM permissions through EKS Pod Identity or IRSA.
- We confirm whether any existing `gp2` class is default.

This is the same professional boundary as earlier tasks: we prepare the code and runbook, but we do not pretend live cluster validation happened before the cluster exists.

## CCPU-48: Echo Service Smoke Test

The echo service is a tiny workload used to test the platform before CPEmon services move onto EKS.

It is deliberately simple:

```text
k8s/samples/echo/deploy.yaml
k8s/samples/echo/svc.yaml
```

It lives in:

```text
platform
```

Why `platform` instead of `cpemon`:

- It is a platform validation object, not a business service.
- It should be easy to delete without touching real workloads.
- It gives networking and ingress tasks a stable target before CPEmon APIs are migrated.

## What Echo Proves

The echo test proves the basic Kubernetes path:

```text
Deployment -> ReplicaSet -> Pod -> readiness -> Service selector -> ClusterIP -> port-forward
```

This is intentionally smaller than an external access test.

`CCPU-48` proves internal Kubernetes workload and Service wiring. `CCPU-49` will prove external access through ALB/Ingress.

## Why Clean Manifests Matter

The old echo YAML looked like a live cluster export. It included fields such as:

```text
creationTimestamp
resourceVersion
uid
status
kubectl.kubernetes.io/last-applied-configuration
```

Those fields belong to the Kubernetes API server, not to Git.

The committed manifests should describe desired state:

- image
- replicas
- labels
- probes
- ports
- resources
- Service selector

Keeping runtime fields in Git creates noisy diffs and can confuse reviews.

## Echo Design

The Deployment uses a fixed image tag:

```text
hashicorp/http-echo:1.0
```

It listens on container port `8080` and returns:

```text
cpemon platform echo ok
```

The Service exposes port `80` and targets the named container port:

```yaml
ports:
  - name: http
    port: 80
    targetPort: http
```

Using a named target port makes the Service easier to read and more resilient if the numeric container port changes later.

## Apply and Validate

After the EKS cluster exists:

```powershell
make echo
make echo-check
```

Local access:

```powershell
make echo-port-forward
curl http://localhost:8080
```

Expected response:

```text
cpemon platform echo ok
```

Troubleshooting starts with:

```powershell
kubectl get deploy,svc,pods -n platform -l app.kubernetes.io/name=echo
kubectl rollout status deployment/echo -n platform
kubectl get endpoints echo -n platform
kubectl logs -n platform -l app.kubernetes.io/name=echo
```

Most common issue:

```text
Service selector does not match Pod labels.
```

## CCPU-49: Expose Echo Through ALB Ingress

External access validation answers this question:

```text
Can traffic from outside the cluster reach a pod through the EKS load balancing path?
```

For this project, the prepared path is AWS Load Balancer Controller with an ALB-backed Kubernetes Ingress:

```text
k8s/samples/echo/ing.yaml
```

The Ingress uses:

```yaml
ingressClassName: alb
alb.ingress.kubernetes.io/scheme: internet-facing
alb.ingress.kubernetes.io/target-type: ip
alb.ingress.kubernetes.io/listen-ports: '[{"HTTP": 80}]'
alb.ingress.kubernetes.io/healthcheck-path: /
```

## Request Path

The request path is:

```text
curl/browser
  -> AWS Application Load Balancer
  -> listener :80
  -> target group
  -> pod IP target
  -> echo Service
  -> echo Pod
```

This is the first task in the story that connects Kubernetes objects to an AWS-managed runtime resource.

The earlier echo task proved:

```text
Deployment -> Pod -> Service -> port-forward
```

This task prepares:

```text
Ingress -> ALB -> target group -> external HTTP access
```

## Why ALB Ingress

AWS Load Balancer Controller creates an ALB from Kubernetes `Ingress`.

It watches the Ingress object and reconciles AWS resources. That means the Ingress manifest is not just a Kubernetes routing rule; it is also a request for AWS infrastructure.

Important dependencies:

- AWS Load Balancer Controller must be running.
- Controller service account must have IAM permissions.
- Public subnets must have EKS load balancer discovery tags.
- Echo Service must have endpoints.
- Echo Pod must be Ready.

## Why Target Type `ip`

The Ingress uses:

```text
alb.ingress.kubernetes.io/target-type: ip
```

With IP target mode, the ALB target group can route directly to pod IPs. This is common for EKS and pairs naturally with AWS VPC CNI networking.

Instance target mode routes to worker node instances and then relies on NodePort-style routing. That can still be valid, but `ip` mode is the cleaner default for this platform smoke test.

## Apply and Validate

After the EKS cluster and AWS Load Balancer Controller exist:

```powershell
make echo
make echo-check
make echo-ingress
make echo-ingress-check
```

Direct checks:

```powershell
kubectl get ingress echo -n platform
kubectl describe ingress echo -n platform
kubectl get ingress echo -n platform -o jsonpath="{.status.loadBalancer.ingress[0].hostname}{'\n'}"
```

When the ALB DNS name appears:

```powershell
curl http://<alb-dns-name>/
```

Expected response:

```text
cpemon platform echo ok
```

If no ALB appears, debug from controller outward:

```powershell
kubectl logs -n kube-system deploy/aws-load-balancer-controller --tail=100
kubectl describe ingress echo -n platform
kubectl get endpoints echo -n platform
```

## CCPU-152: Baseline NetworkPolicy Approach

NetworkPolicy is the Kubernetes-native way to describe pod traffic rules.

The most important mental model:

```text
NetworkPolicy YAML is the policy intent.
The CNI or network-policy engine is what actually enforces it.
```

Kubernetes provides the `NetworkPolicy` API object, but traffic is only restricted if the cluster networking layer supports enforcement. On EKS, that means either:

- Amazon VPC CNI has NetworkPolicy support enabled and configured for the cluster.
- A policy-capable networking layer such as Calico or Cilium is installed and owns enforcement.

Without enforcement, the YAML can exist in the API server while traffic still behaves as allowed. That is a classic interview and real-world pitfall.

## Default Allow vs Default Deny

By default, pods are non-isolated for ingress and egress. In plain words:

```text
No NetworkPolicy selects a pod -> traffic is allowed.
A NetworkPolicy selects a pod for egress -> only allowed egress remains allowed.
A NetworkPolicy selects a pod for ingress -> only allowed ingress remains allowed.
```

This is why a default-deny policy is powerful and dangerous. A simple policy with:

```yaml
podSelector: {}
policyTypes:
  - Egress
```

selects all pods in that namespace and denies all egress unless other egress allow policies also match.

That can instantly break:

- DNS lookups
- calls to databases
- metrics scraping or remote write
- calls to AWS service endpoints
- image pulls or init containers that need external access
- application-to-application traffic that was previously implicit

So the baseline approach is staged instead of broad.

## CPEmon Baseline Decision

For CCPU-152, the current decision is:

```text
Prepare candidate policies, dry-run them, and apply only after EKS CNI enforcement is confirmed.
```

The candidate files live here:

```text
k8s/netpol/baseline/README.md
k8s/netpol/baseline/cpemon-egress-baseline-candidate.yaml
```

The Makefile path is:

```powershell
make netpol-check
make netpol-baseline-plan
```

`netpol-baseline-plan` intentionally uses client dry-run:

```powershell
kubectl apply --dry-run=client -f k8s/netpol/baseline/cpemon-egress-baseline-candidate.yaml
```

That validates manifest structure without enforcing the rules on a live cluster.

## What the Candidate Policy Does

The candidate baseline contains three policies in the `cpemon` namespace.

First, it prepares default-deny egress for all `cpemon` pods:

```text
cpemon-default-deny-egress
```

Second, it allows DNS egress to CoreDNS in `kube-system`:

```text
cpemon-allow-dns-egress
```

This is deliberately separate because almost every application call starts with DNS. If DNS is blocked, errors can look like service outages even when the target service is healthy.

Third, it allows selected CPEmon app pods to call expected internal dependencies:

```text
cpemon-allow-core-app-egress
```

The selected app pods are:

```text
cpemon-api
acs-ingest
cpemon-writer
```

The allowed dependency directions are:

| From | To | Port | Why |
| --- | --- | --- | --- |
| CPEmon core app pods | `mysql` pods in `cpemon` | `3306` | application database access |
| CPEmon core app pods | Prometheus pods in `monitoring` | `9090` | prepared internal monitoring path |

This is not the final production policy. It is a baseline candidate that teaches the pattern:

```text
default-deny first -> explicitly allow DNS -> explicitly allow known dependencies
```

## Why Not Deny Everything Everywhere

The project has several platform namespaces:

```text
platform
monitoring
argocd
kafka
security
cost
kube-system
```

A broad default-deny across all of them would be premature because many add-ons need their own communication patterns:

- AWS Load Balancer Controller talks to the Kubernetes API and AWS APIs.
- metrics-server talks to kubelets.
- EBS CSI and future controllers talk to AWS APIs.
- monitoring tools scrape workloads.
- Argo CD talks to the Kubernetes API and target namespaces.
- DNS runs from `kube-system`.

Applying namespace-wide default-deny before mapping those flows creates outages that teach little and cost time. The professional migration approach is to start with one workload namespace, document expected dependencies, observe traffic, and expand from there.

## EKS-Specific NetworkPolicy Notes

For EKS interviews, connect Kubernetes policy to AWS implementation details:

- EKS pod networking usually uses Amazon VPC CNI, so pods receive VPC-routable IP addresses.
- NetworkPolicy enforcement is not automatic just because the API object exists.
- The CNI version and configuration matter.
- Some workloads and node types may have enforcement limitations depending on the EKS/CNI setup.
- A managed-node Linux EKS path is easier to reason about than mixing in unsupported or differently supported runtime targets too early.

This is why CCPU-152 is a design and preparation task, not a live enforcement task. The cluster has not been applied yet, so we can review the policy model, commit the candidate files, and leave the actual enforcement test for the post-apply phase.

## NetworkPolicy Troubleshooting Checklist

When a service cannot connect after NetworkPolicy is applied, debug in this order:

```powershell
kubectl get networkpolicy -A
kubectl describe networkpolicy -n cpemon
kubectl get pods -n cpemon --show-labels
kubectl get ns --show-labels
kubectl get endpoints -n cpemon
kubectl get endpoints -n monitoring
kubectl logs -n kube-system -l k8s-app=kube-dns --tail=50
```

Common causes:

- `podSelector` does not match the actual pod labels.
- `namespaceSelector` does not match namespace labels.
- DNS egress was forgotten.
- The allowed port is wrong.
- The dependency runs in a different namespace than expected.
- CNI enforcement is disabled, so the policy exists but does not affect traffic.
- CNI enforcement is enabled in a stricter mode than expected, so pods become isolated earlier than planned.

## CCPU-50 Scope Correction

The previous incident-style task for external access drift was removed from the current CCPU-5 scope.

Reason:

```text
There is no applied EKS cluster, no running AWS Load Balancer Controller, no ALB, and no live echo endpoint yet.
```

So a real incident drill such as "Service cannot be reached through ALB or Ingress" would be fake at this stage. The correct move is to keep the external access runbook from CCPU-49 and defer live incident response until the cluster and ALB exist.

## CCPU-153: Platform Makefile Checks and Documentation

The final CCPU-5 task turns the individual checks from earlier subtasks into a repeatable platform verification plan.

The important idea:

```text
Makefile targets are not magic.
They are a shared operational checklist encoded as commands.
```

This matters in a migration because the team needs to separate platform readiness from application bugs. If CPEmon fails after migration, the first question should be:

```text
Is the EKS platform healthy enough to run a simple workload?
```

The platform checks answer that question step by step.

## Check Layers

The check order is:

```text
tooling and cluster access
  -> namespaces
  -> metrics-server
  -> AWS Load Balancer Controller
  -> StorageClass
  -> echo workload
  -> ALB Ingress external access
  -> NetworkPolicy posture
```

Each layer depends on the earlier layers.

Examples:

- `echo-ingress-check` is not meaningful if `aws-lbc-check` fails.
- `aws-lbc-check` is not meaningful if `platform-preflight` cannot reach the cluster.
- `storage-check` can inspect StorageClasses, but PVC provisioning still depends on the EBS CSI driver and its IAM permissions.
- `netpol-check` can list policy objects, but enforcement depends on CNI support.

## New Makefile Entrypoints

Preflight:

```powershell
make platform-preflight
```

This checks local tools and cluster access:

```text
kubectl client
helm
aws CLI
current kubeconfig context
cluster-info
```

Manifest dry-run:

```powershell
make platform-manifest-plan
```

This uses `kubectl apply --dry-run=client` against the prepared manifests:

- namespaces
- gp3 StorageClass candidate
- echo Deployment
- echo Service
- echo ALB Ingress
- NetworkPolicy baseline candidate

Full post-apply platform check:

```powershell
make platform-checks
```

This runs:

```text
platform-preflight
ns-check
metrics-server-check
aws-lbc-check
storage-check
echo-check
echo-ingress-check
netpol-check
```

This target is intentionally post-apply. It should be used after the EKS cluster exists and add-ons/workloads have been installed.

## Why Aggregated Checks Help

Manual commands are easy to forget or run out of order.

A Makefile gives the platform a simple operating surface:

```powershell
make platform-preflight
make platform-manifest-plan
make platform-checks
```

That gives three useful modes:

| Target | Purpose | When to use |
| --- | --- | --- |
| `platform-preflight` | Confirm local tools and cluster connectivity. | Before debugging Kubernetes resources. |
| `platform-manifest-plan` | Validate committed manifests client-side. | Before applying manifests or reviewing PRs. |
| `platform-checks` | Inspect the live platform after installation. | After EKS and add-ons exist. |

For interviews, this is a good operational maturity signal. It shows that the project did not stop at "I wrote YAML." It turned platform expectations into repeatable commands and runbooks.

## Platform Checks Runbook

The runbook is:

```text
ops/runbooks/eks-platform-checks.md
```

It explains:

- what each target checks
- when to run each target
- why the order matters
- how to troubleshoot from the first failed dependency

The current boundary remains:

```text
The EKS cluster has not been applied yet.
The checks are prepared now.
Live execution happens after the cluster exists.
```

## Interview Summary

In the EKS platform add-ons story, I started with namespaces because they are the first Kubernetes boundary for ownership, policy, observability, and deployment separation. I converted namespace creation into a committed manifest instead of relying on one-off `kubectl create namespace` commands. Then I prepared Helm-based installs for metrics-server and AWS Load Balancer Controller, with values files, Makefile targets, runbook commands, and validation checks. I also prepared default StorageClass verification and a candidate encrypted gp3 StorageClass backed by the Amazon EBS CSI driver. Finally, I cleaned and documented a tiny echo service and prepared an ALB-backed Ingress so external access can be validated through the AWS Load Balancer Controller path after the EKS cluster exists.
