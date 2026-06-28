# K8sGPT Backend, Secret, and Anonymization Boundary

## Backend Strategy

The repository models an OpenAI backend for explanation mode, but it does not
commit any real credential.

```text
k8s/k8sgpt/k8sgpt-secret.tmpl.yaml
```

The live Secret must be created by an operator or delivered by External Secrets
Operator in a later task.

## Secret Creation Example

```powershell
kubectl create secret generic k8sgpt-openai `
  -n k8sgpt-operator-system `
  --from-literal=openai-api-key=$env:OPENAI_API_KEY
```

## Privacy Rules

* Enable anonymization for backend analysis.
* Do not include secret values in prompts or runbooks.
* Treat namespace names, service names, and labels as potentially sensitive.
* Keep backend usage optional for offline validation.

## Interview Note

The important answer is that AI integration changes the security model. You
must control what data leaves the cluster, how credentials are stored, and who
can run explained analysis.
