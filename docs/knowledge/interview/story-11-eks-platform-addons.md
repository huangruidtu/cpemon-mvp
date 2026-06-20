# Story 11: EKS Platform Add-ons

## Q1: What is the goal of the EKS platform add-ons story?

The goal is to prepare the shared Kubernetes platform layer before deploying CPEmon workloads onto EKS.

The infrastructure story created AWS and EKS foundations. The add-ons story prepares cluster-level capabilities such as namespaces, metrics, load balancing, storage checks, smoke tests, NetworkPolicy design, and repeatable operational checks.

## Q2: Why start with namespaces?

Namespaces are the first Kubernetes boundary.

They let the platform separate application workloads, platform tests, monitoring, delivery tooling, security tools, cost tooling, and future data systems. Without namespaces, everything lands in `default`, which makes policy, ownership, troubleshooting, and interview explanation weaker.

## Q3: Which namespaces did you create for CPEmon EKS?

The standard namespace set is:

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

`backup` and `ingress-nginx` are retained for compatibility with existing MVP/lab manifests. The EKS direction for external access is AWS Load Balancer Controller, not copying the old lab ingress path as the default.

## Q4: What is each namespace for?

`cpemon` is for application workloads.

`platform` is for platform smoke tests and shared validation resources.

`monitoring` is for observability resources such as Prometheus, Grafana, alerts, and ServiceMonitors.

`argocd` is reserved for future GitOps.

`kafka` is reserved for future streaming and messaging.

`security` is for policy, scanning, and security platform tools.

`cost` is for FinOps and cost visibility.

`backup` supports the existing backup workflow.

`ingress-nginx` supports old lab resources but is not the preferred EKS external access direction.

## Q5: Why use YAML manifests instead of `kubectl create namespace`?

The manifest is repeatable, reviewable, and GitOps-ready.

`kubectl create namespace` is fine for a quick lab, but it does not leave a durable record of labels, ownership, or intended platform structure. In a migration project, the namespace map is infrastructure knowledge, so it belongs in Git.

## Q6: What labels did you add and why?

Each namespace has labels like:

```yaml
app.kubernetes.io/part-of: cpemon-mvp
app.kubernetes.io/name: cpemon
cpemon.io/layer: application
cpemon.io/managed-by: gitops-ready-manifest
```

These labels make the platform model visible. They can support cost allocation, policy targeting, ownership review, and easier cluster inspection.

## Q7: What command applies the namespace manifest?

```powershell
make ns
```

Under the hood, it runs:

```powershell
kubectl apply -f k8s/base/namespaces.yaml
```

## Q8: How do you validate namespaces?

```powershell
make ns-check
```

Equivalent direct commands:

```powershell
kubectl get ns cpemon platform monitoring argocd kafka security cost backup ingress-nginx
kubectl get ns -L cpemon.io/layer,cpemon.io/managed-by
```

## Q9: If namespace validation fails, what do you check first?

Check cluster access before blaming the namespace YAML.

Useful commands:

```powershell
kubectl config current-context
kubectl cluster-info
aws sts get-caller-identity --profile cpemon-terraform
```

If the cluster has not been applied yet, namespace validation cannot run. That is expected in the current plan-only phase.

## Q10: How do namespaces relate to RBAC?

Namespaces provide a boundary that RBAC can target.

For example, a developer or CI/CD service account can later receive edit permission only in `cpemon`, while platform admins retain broader permissions. Namespace separation makes least privilege practical.

## Q11: How do namespaces relate to NetworkPolicy?

NetworkPolicy often uses namespace boundaries to control traffic.

For example, a future policy may allow `cpemon` workloads to talk to monitoring endpoints but deny unrelated egress. Namespace labels can make those policies easier to read and maintain.

## Q12: How do namespaces help in production operations?

They make operational questions easier:

- Where are application pods?
- Where is monitoring?
- Which namespace should own cost tooling?
- Which resources belong to future GitOps?
- Which namespace should an incident runbook inspect first?

This matters because real debugging starts with narrowing the search area.

## Q13: What did you actually change for CCPU-46?

I updated the base namespace manifest, added EKS platform labels, added missing platform namespaces, documented the namespace model, added interview Q&A, and added Makefile validation commands.

The key files are:

```text
k8s/base/namespaces.yaml
Makefile
docs/knowledge/eks-platform-addons.md
docs/knowledge/interview/story-11-eks-platform-addons.md
ops/runbooks/eks-platform-namespaces.md
```

## Q14: How would you summarize this subtask in an interview?

I treated namespaces as a platform design boundary, not just a Kubernetes object. I created a versioned namespace manifest for application, platform, monitoring, delivery, security, cost, backup, and compatibility areas. I added labels so the platform model is inspectable and future policy/cost/GitOps tooling can target it. Because the EKS cluster was not applied yet, I prepared the manifests and validation commands while clearly documenting that live verification happens after cluster creation.

## Q15: What is metrics-server?

metrics-server is the Kubernetes resource metrics component.

It collects recent CPU and memory usage from nodes and pods and exposes those metrics through the Kubernetes Metrics API. That enables commands such as:

```powershell
kubectl top nodes
kubectl top pods -A
```

It also supports autoscaling features such as Horizontal Pod Autoscaler.

## Q16: Is metrics-server the same thing as Prometheus?

No.

metrics-server is for current resource metrics and autoscaling. Prometheus is for scraping, storing, querying, alerting, and dashboarding over time.

The interview-friendly answer is: metrics-server helps Kubernetes make short-term resource decisions; Prometheus helps humans and systems observe behavior over time.

## Q17: Why install metrics-server with Helm?

Helm gives a repeatable add-on installation path.

Instead of applying a remote manifest URL, the project keeps a values file in Git:

```text
k8s/addons/metrics-server/values.yaml
```

That means the chart version, resource requests, labels, and future overrides are reviewable.

## Q18: What command installs metrics-server in this project?

```powershell
make helm-repos
make metrics-server
```

The underlying Helm install is:

```powershell
helm upgrade --install metrics-server metrics-server/metrics-server `
  --namespace kube-system `
  --version 3.13.1 `
  --values k8s/addons/metrics-server/values.yaml
```

## Q19: How do you validate metrics-server?

```powershell
kubectl get deployment -n kube-system metrics-server
kubectl top nodes
kubectl top pods -A
```

If `kubectl top` fails, check whether the cluster exists, nodes are Ready, metrics-server pods are running, and RBAC allows the current identity to read metrics.

## Q20: What is AWS Load Balancer Controller?

AWS Load Balancer Controller is a Kubernetes controller for EKS that manages AWS Elastic Load Balancing resources.

It can create:

- ALB from Kubernetes `Ingress`
- NLB from Kubernetes `Service` of type `LoadBalancer`
- newer Gateway API based ALB resources in supported versions

## Q21: Why prefer AWS Load Balancer Controller on EKS?

Because it integrates directly with AWS load balancing.

The controller understands ALB/NLB behavior, subnet discovery tags, target groups, security groups, and AWS load balancer lifecycle. That is more EKS-native than copying a lab setup based on ingress-nginx and MetalLB.

## Q22: Is ingress-nginx deprecated?

Not as a general Kubernetes project.

The better statement is: for this EKS migration, AWS Load Balancer Controller is the preferred default because it is AWS-native. ingress-nginx can still be used in some architectures, but it should not be copied from the lab as the default EKS external access path without a reason.

## Q23: What IAM setup does AWS Load Balancer Controller need?

The controller needs permission to call AWS APIs for load balancers, target groups, listeners, security groups, and related discovery.

The clean EKS pattern is to bind an IAM role to the controller service account using IRSA or EKS Pod Identity. With IRSA, the service account gets an annotation like:

```text
eks.amazonaws.com/role-arn = arn:aws:iam::<account-id>:role/<aws-lbc-role-name>
```

## Q24: What command installs AWS Load Balancer Controller in this project?

```powershell
make helm-repos
make aws-lbc EKS_VPC_ID=<vpc-id> AWS_LBC_ROLE_ARN=<aws-lbc-role-arn>
```

The values file is:

```text
k8s/addons/aws-load-balancer-controller/values.yaml
```

## Q25: How do you validate AWS Load Balancer Controller?

```powershell
kubectl get deployment -n kube-system aws-load-balancer-controller
kubectl logs -n kube-system deploy/aws-load-balancer-controller --tail=80
```

Later, the stronger validation is to create an `Ingress` for the echo service and confirm that an ALB appears and routes traffic to healthy targets.

## Q26: What did you actually change for CCPU-44 and CCPU-45?

I added Helm values files, Makefile targets, a runbook, and learning documentation.

Key files:

```text
k8s/addons/metrics-server/values.yaml
k8s/addons/aws-load-balancer-controller/values.yaml
ops/runbooks/eks-platform-addons-helm.md
Makefile
docs/knowledge/eks-platform-addons.md
docs/knowledge/interview/story-11-eks-platform-addons.md
```

## Q27: Why did you not run Helm install yet?

The EKS cluster does not exist yet, and this local environment currently does not have `helm` or `kubectl` in PATH.

So the correct engineering result at this stage is prepared, versioned, reviewable Helm configuration plus runbook commands. Live install and validation belong after the EKS apply window.

## Q28: What is a Kubernetes StorageClass?

A StorageClass is a Kubernetes policy for dynamic storage provisioning.

It tells Kubernetes what storage provisioner to use and which parameters should be used when a workload asks for persistent storage.

## Q29: What is the difference between StorageClass, PVC, and PV?

StorageClass is the template or policy.

PersistentVolumeClaim is the workload request.

PersistentVolume is the actual storage object bound to the claim.

In EKS with EBS, the CSI driver creates an AWS EBS volume and Kubernetes represents it as a PersistentVolume.

## Q30: Why does CPEmon care about the default StorageClass?

Because a workload can create a PVC without explicitly naming a storage class.

If the default is unclear or wrong, stateful workloads may get the wrong volume type, no volume at all, or a legacy provisioner. For CPEmon, this matters for MySQL now and Kafka or other stateful components later.

## Q31: What StorageClass direction did you prepare?

I prepared a default `gp3` StorageClass:

```text
k8s/addons/storage/gp3-storageclass.yaml
```

The provisioner is:

```text
ebs.csi.aws.com
```

That is the standard Amazon EBS CSI driver provisioner for non-Auto Mode EKS clusters.

## Q32: Why use gp3 instead of gp2?

`gp3` is the modern EBS general-purpose volume type. It gives a cleaner baseline for new workloads, supports explicit performance settings, and is the direction most new AWS storage designs should prefer.

The interview answer is: for new EKS persistent storage, I would prefer EBS CSI with gp3 instead of relying on older gp2 or in-tree AWS EBS behavior.

## Q33: What is the EBS CSI driver?

The Amazon EBS CSI driver is the Kubernetes storage plugin that calls AWS APIs to create, attach, detach, and manage EBS volumes for Kubernetes workloads.

Without the CSI driver and its IAM permissions, a StorageClass may exist but PVC provisioning can still fail.

## Q34: Why does the EBS CSI driver need IAM permissions?

Because creating a Kubernetes PVC eventually requires AWS API calls to create and attach EBS volumes.

AWS recommends using EKS add-ons and giving the driver permissions through EKS Pod Identity or IRSA. If permissions are missing, PVC events may show `UnauthorizedOperation` or failed provisioning errors.

## Q35: What does `WaitForFirstConsumer` mean?

It delays volume creation until a pod actually needs the PVC.

This matters on AWS because EBS volumes are tied to one Availability Zone. Kubernetes should create the volume in the same AZ where the consuming pod is scheduled.

## Q36: How do you verify the default StorageClass?

```powershell
make storage-check
```

Direct commands:

```powershell
kubectl get storageclass
kubectl describe storageclass
kubectl get storageclass -o custom-columns=NAME:.metadata.name,DEFAULT:.metadata.annotations.storageclass\.kubernetes\.io/is-default-class,PROVISIONER:.provisioner,VOLUME_BINDING:.volumeBindingMode,ALLOW_EXPANSION:.allowVolumeExpansion
```

## Q37: What did you actually change for CCPU-47?

I added a candidate gp3 default StorageClass manifest, Makefile storage checks, a runbook, and interview/knowledge documentation.

Key files:

```text
k8s/addons/storage/gp3-storageclass.yaml
ops/runbooks/eks-storageclass-verification.md
Makefile
docs/knowledge/eks-platform-addons.md
docs/knowledge/interview/story-11-eks-platform-addons.md
```

## Q38: Why did you not apply the StorageClass yet?

The EKS cluster does not exist yet, and the EBS CSI driver/IAM setup has not been applied.

Applying a default StorageClass before the driver exists would create a misleading partial setup. The professional move is to prepare the manifest and validation path, then apply it after EKS and EBS CSI prerequisites are real.

## Q39: Why deploy an echo service before the real app?

An echo service separates platform problems from application problems.

If the echo service cannot run, the issue is likely cluster scheduling, image pull, Service selector, DNS, or networking. That is much easier to debug than a real application with database, config, auth, and business logic.

## Q40: What does the echo service test?

It tests the basic Kubernetes workload path:

```text
Deployment -> ReplicaSet -> Pod -> readiness -> Service -> port-forward
```

It does not yet test external ALB access. That belongs to the next task.

## Q41: Why put echo in the `platform` namespace?

Because it is platform validation, not a CPEmon business workload.

The `platform` namespace makes it clear that this is a disposable test target used by operators while preparing EKS.

## Q42: Why remove `status`, `uid`, and `resourceVersion` from YAML?

Those are runtime fields created by the Kubernetes API server.

Git should store desired state, not live cluster state. Desired state includes labels, replicas, image, probes, ports, and Service selectors. Runtime fields create noise and should not be committed as source manifests.

## Q43: Why avoid `latest` image tags for the echo service?

`latest` is not deterministic.

If the image changes upstream, the same manifest may behave differently tomorrow. A fixed tag makes smoke tests repeatable and easier to explain in a migration project.

## Q44: How do you validate the echo service?

```powershell
make echo
make echo-check
make echo-port-forward
curl http://localhost:8080
```

Expected response:

```text
cpemon platform echo ok
```

## Q45: What is the most common Service debugging issue?

A selector mismatch.

The Service selects pods by label. If the Service selector does not match the Pod template labels, the Service exists but has no endpoints.

Debug with:

```powershell
kubectl get endpoints echo -n platform
kubectl describe svc echo -n platform
kubectl get pods -n platform --show-labels
```

## Q46: What did you actually change for CCPU-48?

I cleaned the echo Deployment and Service manifests, pinned the image tag, added probes and resources, added Makefile targets, and documented the validation path.

Key files:

```text
k8s/samples/echo/deploy.yaml
k8s/samples/echo/svc.yaml
ops/runbooks/eks-echo-service.md
Makefile
docs/knowledge/eks-platform-addons.md
docs/knowledge/interview/story-11-eks-platform-addons.md
```

## Q47: What does CCPU-49 validate?

It validates the external access path for the echo service.

The goal is to prove that an outside client can reach a pod through AWS Load Balancer Controller and an ALB-backed Kubernetes Ingress.

## Q48: What is the request path for echo external access?

```text
curl/browser -> ALB -> listener -> target group -> pod IP -> Service -> Pod
```

That path crosses both AWS infrastructure and Kubernetes objects, which is why it is more complex than `kubectl port-forward`.

## Q49: Why use `ingressClassName: alb`?

It tells Kubernetes and AWS Load Balancer Controller that this Ingress should be reconciled by the ALB controller, not by nginx or another ingress controller.

In this project, old lab Ingress used `nginx`, but EKS external access should use the AWS-native controller.

## Q50: What annotations matter on the ALB Ingress?

Important annotations include:

```text
alb.ingress.kubernetes.io/scheme: internet-facing
alb.ingress.kubernetes.io/target-type: ip
alb.ingress.kubernetes.io/listen-ports: [{"HTTP": 80}]
alb.ingress.kubernetes.io/healthcheck-path: /
```

They control whether the ALB is public, how it targets workloads, which listener port it uses, and how it checks target health.

## Q51: Why use target type `ip`?

With `ip` target type, the ALB target group routes directly to pod IPs.

That fits EKS with AWS VPC CNI because pods receive VPC-routable IP addresses. It avoids using worker nodes as the first target hop for this simple HTTP smoke test.

## Q52: How do you validate the ALB Ingress?

```powershell
make echo-ingress
make echo-ingress-check
```

Direct commands:

```powershell
kubectl get ingress echo -n platform
kubectl describe ingress echo -n platform
kubectl get ingress echo -n platform -o jsonpath="{.status.loadBalancer.ingress[0].hostname}{'\n'}"
curl http://<alb-dns-name>/
```

Expected response:

```text
cpemon platform echo ok
```

## Q53: What do you check if no ALB DNS name appears?

Start with the controller and Ingress events:

```powershell
kubectl logs -n kube-system deploy/aws-load-balancer-controller --tail=100
kubectl describe ingress echo -n platform
```

Then confirm the Service has endpoints:

```powershell
kubectl get endpoints echo -n platform
```

If those look good, check subnet tags, IAM permissions, and AWS target group/load balancer state.

## Q54: What did you actually change for CCPU-49?

I replaced the old nginx-style echo Ingress with an ALB Ingress, added Makefile targets, added an external-access runbook, and expanded the knowledge/interview notes.

Key files:

```text
k8s/samples/echo/ing.yaml
ops/runbooks/eks-echo-external-access.md
Makefile
docs/knowledge/eks-platform-addons.md
docs/knowledge/interview/story-11-eks-platform-addons.md
```

## Q55: Why was the ALB incident drill removed from the current scope?

Because the EKS cluster has not been applied yet.

There is no running control plane, no worker node, no AWS Load Balancer Controller, no ALB, and no live echo endpoint. A task like "service cannot be reached through ALB or Ingress" would be fake until those runtime pieces exist.

The correct migration decision was to keep the external access runbook and defer the live incident drill until after EKS and ALB are real.

## Q56: What is Kubernetes NetworkPolicy?

NetworkPolicy is a Kubernetes API object that describes allowed network traffic for pods.

It can control ingress, egress, or both. The key idea is that policies select pods by labels and then define what those selected pods are allowed to receive or send.

## Q57: Does creating a NetworkPolicy YAML automatically block traffic?

Not always.

Kubernetes stores the `NetworkPolicy` object, but enforcement is done by the cluster networking layer. If the CNI or policy engine does not support or enable NetworkPolicy enforcement, the policy may exist while traffic remains allowed.

This is an important EKS interview point: YAML is intent; the CNI enforces it.

## Q58: How does NetworkPolicy behave by default?

By default, pods are non-isolated.

If no NetworkPolicy selects a pod, traffic is allowed. Once a policy selects a pod for ingress or egress, only traffic explicitly allowed by matching policies remains allowed for that direction.

## Q59: What is a default-deny policy?

A default-deny policy selects pods and provides no allow rules for a traffic direction.

For example, a namespace-wide egress default-deny uses:

```yaml
podSelector: {}
policyTypes:
  - Egress
```

That means every pod in the namespace is selected for egress isolation. Without additional allow policies, those pods cannot make outbound connections.

## Q60: Why is default-deny risky?

Because many dependencies are invisible until they break.

A broad default-deny can block DNS, database connections, metrics scraping, controller calls, webhooks, cloud API calls, and application-to-application traffic. In a migration, that can create outages before the team has mapped the runtime traffic.

The safer approach is staged: start with one namespace, allow DNS first, then allow known dependencies.

## Q61: Why did we prepare a candidate policy instead of applying it?

Because the cluster does not exist yet, and NetworkPolicy enforcement has not been confirmed.

The candidate policy gives us a reviewable baseline and a dry-run command. The apply step should happen only after EKS exists, kubeconfig works, the CNI enforcement mode is understood, and workload labels are confirmed.

## Q62: What did the CCPU-152 candidate policy include?

It included three policy objects for the `cpemon` namespace:

```text
cpemon-default-deny-egress
cpemon-allow-dns-egress
cpemon-allow-core-app-egress
```

The pattern is:

```text
deny unexpected egress -> allow DNS -> allow known application dependencies
```

## Q63: Why allow DNS separately?

DNS is a foundational dependency.

Most application connections start by resolving a service name or external hostname. If DNS is blocked, symptoms often look like the target service is down even though the real problem is name resolution.

That is why the baseline has a dedicated DNS allow policy to `kube-system` CoreDNS on TCP and UDP port `53`.

## Q64: What are `podSelector` and `namespaceSelector`?

`podSelector` matches pods by labels.

`namespaceSelector` matches namespaces by labels.

Together, they let a policy say things like: selected app pods in `cpemon` may call pods with label `app.kubernetes.io/name=mysql` in namespaces with label `app.kubernetes.io/name=cpemon`.

The selectors are label-based, so incorrect labels are one of the most common NetworkPolicy bugs.

## Q65: What EKS-specific detail matters for NetworkPolicy?

On EKS, pod networking commonly uses Amazon VPC CNI.

The important detail is that NetworkPolicy enforcement depends on CNI support and configuration. You should not assume policies are enforced just because EKS accepts the YAML.

In an interview, I would say: first confirm the EKS CNI or chosen policy engine supports and enforces NetworkPolicy, then apply policies gradually and verify with real connectivity tests.

## Q66: Why not apply default-deny to all namespaces now?

Because platform namespaces have controller traffic that must be understood first.

Examples include metrics-server, AWS Load Balancer Controller, EBS CSI, CoreDNS, monitoring, Argo CD, and future security/cost tools. Blocking all of them at once would create noisy failures and make troubleshooting harder.

The professional path is to start with the application namespace and expand once dependencies are mapped.

## Q67: How do you validate the candidate policy before live apply?

Use a dry-run:

```powershell
make netpol-baseline-plan
```

Under the hood:

```powershell
kubectl apply --dry-run=client -f k8s/netpol/baseline/cpemon-egress-baseline-candidate.yaml
```

After a cluster exists, also inspect:

```powershell
make netpol-check
kubectl get pods -n cpemon --show-labels
kubectl get ns --show-labels
```

## Q68: What do you check if traffic breaks after applying NetworkPolicy?

Start with selectors and DNS.

Check whether the policy selects the intended pods, whether namespace labels match, whether DNS egress is allowed, and whether the destination port is correct.

Useful commands:

```powershell
kubectl describe networkpolicy -n cpemon
kubectl get pods -n cpemon --show-labels
kubectl get ns --show-labels
kubectl get endpoints -n cpemon
kubectl get endpoints -n monitoring
```

## Q69: What did you actually change for CCPU-152?

I removed the fake live incident drill from the active path, created a conservative baseline NetworkPolicy candidate, added Makefile dry-run/check targets, added a runbook, and expanded the knowledge/interview notes.

Key files:

```text
k8s/netpol/baseline/README.md
k8s/netpol/baseline/cpemon-egress-baseline-candidate.yaml
ops/runbooks/eks-networkpolicy-baseline.md
Makefile
docs/knowledge/eks-platform-addons.md
docs/knowledge/interview/story-11-eks-platform-addons.md
```

## Q70: How would you summarize the NetworkPolicy approach in an interview?

I would explain that NetworkPolicy is a Kubernetes API for describing allowed pod traffic, but enforcement depends on the CNI or policy engine. For this EKS migration, I did not apply broad default-deny blindly. I prepared a staged baseline for the `cpemon` namespace: deny unexpected egress, allow DNS, then allow known dependencies such as MySQL and monitoring. Because the EKS cluster was not applied yet, I kept the policy as a candidate with dry-run validation and documented the post-apply checks needed before enforcement.

## Q71: Why add platform Makefile checks?

Makefile checks turn manual operational commands into repeatable team workflows.

Instead of asking every engineer to remember the exact `kubectl`, `helm`, and validation commands, the project exposes stable targets such as:

```powershell
make platform-preflight
make platform-manifest-plan
make platform-checks
```

That improves repeatability, onboarding, incident response, and interview clarity.

## Q72: What is the difference between `platform-preflight`, `platform-manifest-plan`, and `platform-checks`?

`platform-preflight` checks local tools and cluster access.

`platform-manifest-plan` checks committed manifests with client-side dry-run.

`platform-checks` inspects the live platform after the cluster and add-ons exist.

The split matters because these answer different questions:

```text
Can my machine talk to the cluster?
Are the manifests structurally valid?
Is the live platform actually healthy?
```

## Q73: Why not put every command into one huge target only?

Because different checks belong to different phases.

Before the cluster exists, live checks cannot pass. After the cluster exists, dry-run alone is not enough. During an incident, a focused single-purpose target is often better than a full platform check.

The project keeps both:

```text
small targets for focused debugging
aggregate targets for platform readiness
```

## Q74: What does `platform-preflight` check?

It checks:

```text
kubectl client
helm
aws CLI
current kubeconfig context
cluster-info
```

This catches basic local and access problems before debugging Kubernetes resources.

If `kubectl cluster-info` fails, there is no point debugging an Ingress manifest yet.

## Q75: What does `platform-manifest-plan` check?

It runs `kubectl apply --dry-run=client` against prepared manifests:

```text
namespaces
gp3 StorageClass
echo Deployment
echo Service
echo ALB Ingress
NetworkPolicy candidate
```

This is a lightweight Kubernetes plan step. It does not create resources, but it catches YAML and client-side schema mistakes.

## Q76: What does `platform-checks` check?

It runs the post-apply platform inspection chain:

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

That covers access, namespaces, add-ons, storage, smoke workload, external access, and network policy posture.

## Q77: How do you troubleshoot if `platform-checks` fails?

Debug in dependency order, not from the noisiest symptom.

For example, if `echo-ingress-check` fails, first check:

```powershell
make aws-lbc-check
make echo-check
```

The ALB Ingress cannot work if the controller is not running or the echo Service has no endpoints.

## Q78: Why is this useful in a migration project?

Migration failures can come from many layers: AWS infrastructure, kubeconfig, cluster add-ons, storage, workload manifests, external load balancing, or network policy.

Makefile checks create a shared readiness ladder. They help the team prove the platform basics before blaming application code.

## Q79: What did you actually change for CCPU-153?

I added aggregate Makefile targets for preflight, manifest dry-run, and full platform checks. I also added a platform checks runbook and expanded the knowledge/interview documentation.

Key files:

```text
Makefile
ops/runbooks/eks-platform-checks.md
docs/knowledge/eks-platform-addons.md
docs/knowledge/interview/story-11-eks-platform-addons.md
```

## Q80: How would you summarize the CCPU-5 story in an interview?

I built the first EKS platform add-on layer above the Terraform-provisioned cluster foundation. I prepared namespace boundaries, Helm-based metrics-server and AWS Load Balancer Controller installs, StorageClass verification, an echo smoke workload, ALB Ingress exposure, a staged NetworkPolicy baseline, and repeatable Makefile checks. Because the EKS cluster had not been applied yet, I clearly separated prepared manifests and runbooks from live validation. That shows migration discipline: define the platform operating model first, then run the live checks when the infrastructure exists.
