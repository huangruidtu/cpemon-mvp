# Story 19 - Argo Rollouts Canary Deployment

## Interview Narrative

I introduced Argo Rollouts as CPEmon's progressive delivery layer. The first
step was not changing the application Deployment; it was installing the shared
controller through GitOps, pinning the chart version, documenting the namespace
and ownership boundary, and validating that the controller can reconcile
Rollout and Analysis resources before the application depends on them.

## Q1: Why is Argo Rollouts platform delivery infrastructure?

Argo Rollouts installs CRDs and a controller that can manage progressive
delivery for many workloads. That makes it a shared delivery control plane, not
an application library. CPEmon should define its Rollout strategy, but it should
not install the controller inside its own application chart.

## Q2: Why install the controller before replacing the Deployment?

A `Rollout` resource cannot reconcile until the CRD and controller exist. If I
convert the application first, the cluster may reject the manifest or leave the
rollout unmanaged. Installing the controller first creates a safe dependency
order.

## Q3: What did CCPU-114 add?

It added an Argo CD Application named `argo-rollouts-dev`, a pinned
`argo-rollouts` Helm chart version, controller values, the `argo-rollouts`
namespace boundary, AppProject source/destination permissions, a runbook, a
knowledge note, and static validation.

## Q4: Why pin the chart version?

Pinning makes the GitOps desired state reproducible. Without a pinned chart
version, the same commit could render different controller manifests later,
which is risky for CRDs and delivery controllers.

## Q5: How would you validate the controller?

I would validate in layers: first run the repository script, then render the
Helm chart locally, then inspect the Argo CD Application, controller Deployment,
pods, services, and CRDs in the live cluster.

## Q6: What is the difference between Argo CD and Argo Rollouts?

Argo CD reconciles Git desired state into Kubernetes. Argo Rollouts controls
how a workload progresses from one version to another using strategies such as
canary, blue-green, manual promotion, abort, and metric-based analysis.

## Q7: What is the most important ownership boundary?

The platform owns the controller and CRDs. The application owns the Rollout,
services, canary steps, and analysis references for its own workload. That
boundary prevents application teams from accidentally duplicating or upgrading
shared delivery infrastructure.

## Q8: Why add the kubectl Argo Rollouts plugin?

The plugin gives operators a purpose-built CLI for progressive delivery. Plain
`kubectl get rollout` can show the resource, but the plugin gives clearer
commands for status, watch, promote, abort, retry, and dashboard-style
inspection. That matters in demos and incidents because rollout decisions are
time-sensitive.

## Q9: Is the plugin required for the controller to work?

No. The controller runs in the cluster and reconciles Rollout resources whether
or not my laptop has the plugin. The plugin is local tooling for humans. I keep
that distinction clear because production automation should not depend on one
developer machine.

## Q10: What local tooling issue did you validate on Windows?

The plugin binary existed at `C:\Users\Rui Huang\bin\kubectl-argo-rollouts.exe`,
but the current shell did not have that directory in `PATH`. `kubectl` only
discovers plugins when the executable follows the `kubectl-...` naming
convention and is visible on `PATH`. After prepending the directory, `kubectl
argo rollouts version` reported `v1.9.0+838d4e7`.

## Q11: Why migrate only cpemon-api to Rollout first?

`cpemon-api` is the right first candidate because it is the user-facing API
where canary behavior is easy to explain through HTTP success rate and latency.
Keeping `acs-ingest` and `cpemon-writer` as Deployments reduces blast radius and
avoids mixing progressive delivery with producer/consumer semantics too early.

## Q12: What did the Rollout migration preserve?

It preserved the same pod template contract: labels, selector, image,
environment variables, Secret references, ports, probes, resources, affinity,
tolerations, Service selector, and ServiceMonitor compatibility. Only the
workload controller kind changes when `workloads.cpemonApi.rollout.enabled` is
true.

## Q13: Why use empty canary steps at first?

Empty steps make the first change about the controller-kind migration, not
about traffic shifting. That is easier to validate and review. Later subtasks
can add stable/canary Services, weights, pauses, and Prometheus analysis after
the Rollout resource itself is rendering correctly.

## Q14: Why add stable and canary Services?

The stable Service represents traffic that should continue going to the proven
ReplicaSet. The canary Service represents traffic that can reach the new
ReplicaSet while it is being evaluated. Argo Rollouts uses those Service
boundaries to separate old and new versions during progressive delivery.

## Q15: Why keep the existing cpemon-api Service?

Keeping `cpemon-api` avoids breaking existing ingress, monitoring, and operator
habits while the Rollouts migration is introduced. The new `cpemon-api-stable`
and `cpemon-api-canary` Services are progressive-delivery boundaries; the
original Service remains the application entrypoint until routing is fully
decided.

## Q16: How do you inspect which ReplicaSet a Service targets?

I would inspect the Service selector and endpoints:

```powershell
kubectl describe svc cpemon-api-stable -n cpemon
kubectl describe svc cpemon-api-canary -n cpemon
kubectl get endpoints cpemon-api-stable cpemon-api-canary -n cpemon
kubectl argo rollouts get rollout cpemon-api -n cpemon
```

The important idea is that the Service selector and endpoints show where
traffic can actually go, while the Rollout status explains the rollout phase.

## Q17: Why use 20%, pause, 50%, pause, 100%?

It gives a simple gradual exposure path. At 20%, the new version gets real
traffic but the stable version still serves most users. At 50%, the team sees
whether behavior holds under more load. The pauses create inspection windows
before the operator promotes further.

## Q18: What do the pauses mean operationally?

The pauses are deliberate decision points. During a pause, I would inspect
Rollout status, service endpoints, dashboards, HTTP 5xx rate, latency, logs,
and traces. If the canary looks bad, I abort. If it looks healthy, I promote.

## Q19: Why not add Prometheus analysis in the same step?

Separating the steps keeps the migration teachable. First I prove the Rollout
resource, then Services, then manual canary steps, then automated metric-based
analysis. That sequence makes each failure mode easier to debug and explain.

## Q20: Why use HTTP 5xx rate as the first analysis signal?

5xx rate is a direct API reliability signal. If the canary creates server-side
errors, the rollout should stop before more users are exposed. It is also easy
to explain from RED metrics: request rate, error rate, and duration.

## Q21: Why use a ratio instead of a raw 5xx count?

A raw count depends on traffic volume. Five errors during ten requests is very
different from five errors during ten thousand requests. A ratio makes the
threshold meaningful across different traffic levels.

## Q22: Why is the Prometheus query low-cardinality?

The query filters on bounded labels such as HTTP status code. It does not group
by device serial number, raw route parameter, payload value, or customer ID.
That keeps Prometheus cardinality controlled during canary analysis.

## Q23: Why add p95 latency analysis in addition to 5xx analysis?

5xx analysis catches failed requests, but a canary can be bad even when it still
returns 200. p95 latency catches slow successful requests and protects user
experience during promotion.

## Q24: Why use `histogram_quantile`?

Prometheus histograms store request durations in buckets. `histogram_quantile`
is the standard way to estimate quantiles such as p95 from those buckets. The
query must keep the `le` bucket label, so it uses `sum by (le)`.

## Q25: What does `result[0] < 0.5` mean?

It means the p95 latency returned by the Prometheus query must be below 0.5
seconds. For this dev learning environment, that is a clear threshold that is
easy to explain and tune later.

## Q26: Where did you attach the analysis gates?

I attached both the 5xx-rate and p95-latency AnalysisTemplates after the 20%
pause and again after the 50% pause. That means the rollout checks health
before increasing exposure and checks again under higher traffic before full
promotion.

## Q27: Why run both 5xx and p95 checks together?

They cover different failure modes. 5xx catches failed requests. p95 catches
slow successful requests. A canary should pass both reliability and latency
signals before getting more traffic.

## Q28: What is an AnalysisRun?

An AnalysisRun is the runtime execution of an AnalysisTemplate. The template
defines the Prometheus query and thresholds; the Rollout creates AnalysisRuns
during promotion and uses their result to continue, pause, or fail the rollout.
