{{/*
Return the chart name. This helper keeps names consistent across templates.
*/}}
{{- define "cpemon.name" -}}
{{- default .Chart.Name .Values.nameOverride | trunc 63 | trimSuffix "-" -}}
{{- end -}}

{{/*
Return the fully qualified release name.
*/}}
{{- define "cpemon.fullname" -}}
{{- if .Values.fullnameOverride -}}
{{- .Values.fullnameOverride | trunc 63 | trimSuffix "-" -}}
{{- else -}}
{{- $name := default .Chart.Name .Values.nameOverride -}}
{{- if contains $name .Release.Name -}}
{{- .Release.Name | trunc 63 | trimSuffix "-" -}}
{{- else -}}
{{- printf "%s-%s" .Release.Name $name | trunc 63 | trimSuffix "-" -}}
{{- end -}}
{{- end -}}
{{- end -}}

{{/*
Common labels recommended by Kubernetes and Helm.
*/}}
{{- define "cpemon.labels" -}}
helm.sh/chart: {{ printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" | quote }}
app.kubernetes.io/name: {{ include "cpemon.name" . | quote }}
app.kubernetes.io/instance: {{ .Release.Name | quote }}
app.kubernetes.io/version: {{ .Chart.AppVersion | quote }}
app.kubernetes.io/managed-by: {{ .Release.Service | quote }}
{{- with .Values.global.commonLabels }}
{{- toYaml . | nindent 0 }}
{{- end }}
{{- end -}}

{{/*
Namespace to use for rendered resources.
*/}}
{{- define "cpemon.namespace" -}}
{{- default .Release.Namespace .Values.global.namespaceOverride -}}
{{- end -}}

{{/*
Labels that must stay stable between Deployments, Services, monitors, and PDBs.
*/}}
{{- define "cpemon.workloadLabels" -}}
{{- $root := .root -}}
{{- $workload := .workload -}}
app: {{ $workload.name | quote }}
{{ include "cpemon.labels" $root }}
app.kubernetes.io/component: {{ $workload.component | quote }}
{{- end -}}

{{/*
Selector labels are intentionally small because Deployment selectors are immutable.
*/}}
{{- define "cpemon.selectorLabels" -}}
{{- $workload := .workload -}}
app: {{ $workload.name | quote }}
app.kubernetes.io/instance: {{ .root.Release.Name | quote }}
app.kubernetes.io/component: {{ $workload.component | quote }}
{{- end -}}

{{/*
Resolve the final container image from global defaults plus workload overrides.
*/}}
{{- define "cpemon.image" -}}
{{- $root := .root -}}
{{- $workload := .workload -}}
{{- $registry := trimSuffix "/" $root.Values.global.imageRegistry -}}
{{- $tag := default $root.Values.global.imageTag $workload.image.tag -}}
{{- printf "%s/%s:%s" $registry $workload.image.repository $tag -}}
{{- end -}}

{{/*
Resolve the final imagePullPolicy from workload override or global default.
*/}}
{{- define "cpemon.imagePullPolicy" -}}
{{- default .root.Values.global.imagePullPolicy .workload.image.pullPolicy -}}
{{- end -}}

{{/*
Render plain env values and Secret-backed env values from the values model.
*/}}
{{- define "cpemon.env" -}}
{{- $root := .root -}}
{{- range .env }}
- name: {{ .name | quote }}
{{- if hasKey . "value" }}
  value: {{ .value | quote }}
{{- else if hasKey . "valueFromConfig" }}
  value: {{ index $root.Values.appConfig .valueFromConfig | quote }}
{{- end }}
{{- end }}
{{- range .secretEnv }}
- name: {{ .name | quote }}
  valueFrom:
    secretKeyRef:
      name: {{ .secretName | quote }}
      key: {{ .secretKey | quote }}
{{- end }}
{{- end -}}

{{/*
Default affinity keeps same-workload replicas apart where possible and prefers worker nodes.
*/}}
{{- define "cpemon.affinity" -}}
{{- $root := .root -}}
{{- $workload := .workload -}}
{{- if $root.Values.podScheduling.affinity }}
{{- toYaml $root.Values.podScheduling.affinity -}}
{{- else if $root.Values.podScheduling.preferWorkerNodes }}
podAntiAffinity:
  preferredDuringSchedulingIgnoredDuringExecution:
    - weight: 100
      podAffinityTerm:
        topologyKey: kubernetes.io/hostname
        labelSelector:
          matchLabels:
            app: {{ $workload.name | quote }}
nodeAffinity:
  preferredDuringSchedulingIgnoredDuringExecution:
    - weight: 100
      preference:
        matchExpressions:
          - key: {{ $root.Values.podScheduling.workerNodeLabelKey | quote }}
            operator: In
            values:
              - {{ $root.Values.podScheduling.workerNodeLabelValue | quote }}
{{- end }}
{{- end -}}

{{/*
Default tolerations preserve the MVP behavior of allowing scheduling on compact lab clusters.
*/}}
{{- define "cpemon.tolerations" -}}
{{- $root := .root -}}
{{- if $root.Values.podScheduling.tolerations }}
{{- toYaml $root.Values.podScheduling.tolerations -}}
{{- else if $root.Values.podScheduling.tolerateControlPlane }}
- key: node-role.kubernetes.io/control-plane
  operator: Exists
  effect: NoSchedule
- key: node-role.kubernetes.io/master
  operator: Exists
  effect: NoSchedule
{{- end }}
{{- end -}}
