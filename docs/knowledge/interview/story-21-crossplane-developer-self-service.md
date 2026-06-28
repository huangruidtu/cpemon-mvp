# Story 21 Interview Q&A: Crossplane Developer Self-Service

## Q1: What is the goal of this story?

The goal is to introduce Crossplane as a developer self-service infrastructure
layer. Developers should be able to request approved application-level cloud
resources through Kubernetes claims and GitOps pull requests, while the platform
team owns the provider configuration, XRDs, Compositions, guardrails, and
lifecycle behavior.

## Q2: What did CCPU-216 add?

It defined the Terraform and Crossplane ownership boundary. Terraform remains
responsible for the platform foundation, while Crossplane is introduced for
selected app-level self-service resources.

## Q3: What stays Terraform-owned?

VPC, subnets, EKS cluster, node groups, baseline IAM, GitHub OIDC, remote state,
cluster access, and foundational platform wiring stay Terraform-owned because
they are high-blast-radius resources that need explicit plan review.

## Q4: What can Crossplane own?

Crossplane can own selected app-level self-service resources such as S3 bucket
claims, DynamoDB table claims, optional ECR repository claims, and future queue
or topic claims once guardrails are in place.

## Q5: Why not replace Terraform with Crossplane?

Replacing Terraform would create unnecessary risk. Terraform is already the
foundation workflow for the EKS platform. Crossplane adds value as a platform
API for developers, not as a replacement for the foundational IaC model.

## Q6: What problem does the boundary prevent?

It prevents two control planes from managing the same AWS resource. If Terraform
and Crossplane both own the same resource, drift, rollback, and incident
ownership become unclear.

## Q7: How would you explain this in an interview?

I would say Terraform owns the platform foundation, and Crossplane exposes
selected app-level capabilities through safe Kubernetes APIs. Developers submit
claims through GitOps, while platform engineers own the abstractions and
guardrails.

## Q8: What did CCPU-217 add?

It added Crossplane as a GitOps-managed platform add-on. The repository now has
a `crossplane-system` namespace, Crossplane Helm values, a `crossplane-dev`
Argo CD Application, an installation runbook, and an offline validation script.

## Q9: Why separate Crossplane installation from ProviderConfig and claims?

The controller must be healthy before providers, XRDs, Compositions, or claims
can reconcile. Separating those layers makes debugging easier and gives each
piece its own review and validation boundary.

## Q10: What should you not claim after CCPU-217?

Do not claim real AWS provisioning. This task only adds the GitOps installation
path for the Crossplane control plane. AWS provisioning needs provider
installation, ProviderConfig, IRSA, claims, and a live EKS/AWS environment.

## Q11: What did CCPU-218 add?

It added the AWS Provider configuration boundary for Crossplane: provider
package manifests, a provider runtime config with an IRSA role annotation, an
`aws-dev-irsa` `ProviderConfig`, a runbook, and an offline validation script.

## Q12: Why use IRSA for Crossplane AWS authentication?

IRSA lets the provider controller pod assume an AWS IAM role through the EKS
OIDC provider. This avoids long-lived AWS keys in Kubernetes secrets and keeps
the cloud permissions attached to a Kubernetes service account boundary.

## Q13: Does CCPU-218 prove AWS provisioning works?

No. It proves the repository has the provider and authentication manifests.
Live provisioning requires a real role ARN, trust policy, provider health, and a
claim that successfully creates an AWS resource.

## Q14: What did CCPU-219 add?

It defined the Crossplane platform API conventions before adding concrete
resource claims. The repository now documents API group naming, claim labels,
developer-controlled fields, platform-controlled fields, resource classes,
deletion policy expectations, and cost metadata.

## Q15: Why define the platform API before writing S3 or DynamoDB claims?

Because Crossplane is being used as a product-like platform API. If the API
contract is not defined first, each resource type can drift into a different
shape. Defining the contract first makes later XRDs, Compositions, policies,
and interview explanations consistent.

## Q16: What should developers be allowed to configure?

Developers should configure approved business and sizing inputs such as
environment, owner, cost center, region, resource class, and a small number of
resource-specific parameters. They should not configure raw provider fields,
IAM behavior, encryption defaults, or provider credentials.

## Q17: What did CCPU-220 add?

It added the first concrete Crossplane platform API: an S3 bucket. The work
includes a namespaced XRD, a pipeline Composition, the patch-and-transform
function package, a developer request example for `cpemon-api`, a runbook, and
an offline validation script.

## Q18: Why is the S3 example called a developer request instead of only a claim?

Crossplane v2 emphasizes namespaced composite resources. Older Crossplane
patterns used separate claim objects. The repository keeps the `claims`
directory name because it is still the developer self-service request area, but
the object itself is a namespaced `XCPemonBucket`.

## Q19: What does the S3 Composition hide from developers?

It hides the AWS provider config, external bucket name construction, mandatory
tags, provider API details, and composition update policy. Developers only
choose approved parameters such as environment, owner, cost center, region,
resource class, deletion policy, and a bucket suffix.

## Q20: What did CCPU-221 add?

It added a DynamoDB table platform API with a namespaced XRD, pipeline
Composition, developer request example, runbook, and offline validation script.
The API exposes approved fields like partition key, billing mode, owner, cost
center, region, and deletion policy.

## Q21: Why only allow PAY_PER_REQUEST in the first DynamoDB version?

Because the platform does not yet have production traffic evidence for
provisioned throughput. `PAY_PER_REQUEST` is simpler for a self-service
developer path and avoids capacity tuning becoming part of the first API
contract.

## Q22: What does the DynamoDB Composition hide?

It hides provider configuration, table external name construction, mandatory
tags, and provider-specific implementation details. Developers get a safer API
for a table request instead of direct access to the raw AWS provider schema.

## Q23: What did CCPU-222 add?

It added an optional ECR repository self-service extension with a namespaced
XRD, pipeline Composition, developer request example, runbook, and offline
validator. The API is intentionally narrow: immutable tags, scan-on-push,
approved regions, required cost metadata, and the `aws-dev-irsa` provider
boundary.

## Q24: Why implement ECR instead of deferring it?

ECR is close to developer delivery and small enough to fit the same platform
API model as S3 and DynamoDB. Implementing it shows how Crossplane can expose a
consistent self-service pattern across storage, database, and image repository
resources.

## Q25: What is the main ECR guardrail?

The main guardrail is release traceability: immutable tags and scan-on-push are
part of the platform API. Developers can request a repository, but they cannot
turn the registry into an unsafe mutable image store through the self-service
contract.

## Q26: What did CCPU-223 add?

It added the developer self-service request layout: a top-level claims README,
a `cpemon-api` dev folder README, a kustomization that groups the S3,
DynamoDB, and ECR requests, a runbook, and an offline validator.

## Q27: Why does the folder layout matter?

The folder layout turns Crossplane from a set of platform manifests into a
developer workflow. App teams know where to request resources, reviewers know
what to inspect, and Argo CD can later reconcile the same directory through
GitOps.

## Q28: Who owns what in the self-service workflow?

Developers own request intent and metadata such as environment, owner, cost
center, and resource-specific suffixes. Platform engineers own XRDs,
Compositions, ProviderConfig, IRSA, guardrails, and review policy.

## Q29: What did CCPU-224 add?

It wired the Crossplane layers through Argo CD Applications: providers and
functions, platform APIs, and developer requests. The sync order is controller,
providers/functions, XRDs and Compositions, then application requests.

## Q30: Why separate provider, platform API, and claim Applications?

Because they have different owners and failure modes. Provider issues are IAM
or control-plane problems, platform API issues are schema/composition problems,
and request issues are developer intent problems. Separate Argo CD Applications
make that operational boundary visible.

## Q31: What did CCPU-225 add?

It added Kyverno guardrails for Crossplane developer requests. The policy
requires ownership and cost metadata, restricts environment/region/resource
class/deletion-policy combinations, and forces ECR requests to use immutable
tags plus scan-on-push.

## Q32: Why does Crossplane self-service need Kyverno?

Because an abstraction without admission control can still be misused. XRD
schemas define the API shape, but Kyverno enforces organizational policy at
admission time: labels, cost ownership, approved regions, deletion behavior,
and safe ECR defaults.

## Q33: What invalid cases are documented?

The fixtures cover missing cost-center metadata, an unapproved AWS region, and
an unsafe ECR repository with mutable tags and scan-on-push disabled.

## Q34: What did CCPU-226 add?

It documented how applications consume Crossplane outputs. The repository now
has a placeholder ConfigMap/Secret example and a runbook explaining what should
be ConfigMap data, what should be Secret data, and where External Secrets
Operator fits.

## Q35: How do Crossplane connection outputs differ from External Secrets?

External Secrets pulls existing secrets from systems such as AWS Secrets Manager
into Kubernetes. Crossplane connection outputs are produced by resource
reconciliation. They may later be written to Kubernetes Secrets or an external
store, but they come from a different lifecycle.

## Q36: Why use placeholders in the example Secret?

Because no live AWS reconciliation has been proven in this task. The placeholder
documents the expected shape without pretending that real bucket, table, or
repository outputs already exist.

## Q37: What did CCPU-227 add?

It added a story-level offline validation script, `verify-crossplane-story.ps1`,
plus a runbook explaining what offline validation proves and what still requires
live EKS/AWS validation.

## Q38: What does offline validation prove?

It proves repository consistency: expected files exist, scripts pass, Argo CD
Applications point at the right paths, XRDs and Compositions are present,
developer examples are wired, guardrails exist, and documentation is indexed.

## Q39: What does offline validation not prove?

It does not prove Crossplane controller health, provider package health, IRSA
trust policy correctness, actual AWS resource creation, connection secret
emission, or live Kyverno admission behavior.
