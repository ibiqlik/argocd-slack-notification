# argocd-slack-notification

To be used with ArgoCD Hooks for sending Slack attachment

## Helm templates

`values.yaml`
```
argocd:
  enabled: true
  namespace:
  url:
  appName:
  slack:
    webhookUrl:
    channel:
    hooks:
      - PostSync
      - SyncFail
...
```

`secrets.yaml`

Provide either `argocdAdminPass` or `argocdToken` but recommended if you create a `GET` only Role in ArgoCD and static token.

```
apiVersion: v1
kind: Secret
metadata:
  name: argo-hook-secrets
  namespace: {{ .Values.namespace }}
stringData:
  argocdAdminPass: ""
  argocdToken: ""
  githubToken: ""
```


`slackstatus.yaml`
```
{{- if .Values.argocd.enabled }}
{{- range $hook := $.Values.argocd.slack.hooks }}
apiVersion: batch/v1
kind: Job
metadata:
  generateName: slack-commit-status-
  namespace: {{ $.Values.argocd.namespace }}
  annotations:
    argocd.argoproj.io/hook: {{ $hook }}
    argocd.argoproj.io/hook-delete-policy: HookSucceeded
spec:
  template:
    spec:
      containers:
      - name: slack-status-post
        image: ilirbekteshi/argocd-github-status
        env:
          - name: ARGOCD_HOOKSTATE
            value: {{ $hook }}
          - name: ARGOCD_SERVER
            value: {{ $.Values.argocd.url }}
          - name: ARGOCD_APP
            value: {{ $.Values.argocd.appName }}
          - name: ARGOCD_TOKEN
            valueFrom:
              secretKeyRef:
                name: argo-hook-secrets
                key: argocdToken
          - name: SLACK_WEBHOOK_URL
            value: {{ $.Values.argocd.slack.webhookUrl }}
          - name: SLACK_CHANNEL
            value: {{ $.Values.argocd.slack.channel }}
      restartPolicy: Never
  backoffLimit: 4
---
{{- end }}
{{- end }}
```

If you use Admin password then change
```
- name: ARGOCD_TOKEN
  valueFrom:
    secretKeyRef:
      name: argo-hook-secrets
      key: argocdToken

to 

- name: ARGOCD_ADMIN_PASS
  valueFrom:
    secretKeyRef:
    name: argo-hook-secrets
    key: argocdAdminPass
```
