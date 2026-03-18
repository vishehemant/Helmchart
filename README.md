# Helm + Argo CD GitOps Lab

A complete, hands-on lab that teaches you how to build **reusable Helm charts**, manage **multi-environment configurations**, integrate with **Argo CD for GitOps**, and automate **upgrades and rollbacks** in Kubernetes.

---

## Table of Contents

1. [Lab Overview](#lab-overview)
2. [Architecture Diagram](#architecture-diagram)
3. [Repository Structure](#repository-structure)
4. [Prerequisites](#prerequisites)
5. [Lab 1 - Helm Fundamentals](#lab-1---helm-fundamentals)
6. [Lab 2 - Building a Reusable Helm Chart](#lab-2---building-a-reusable-helm-chart)
7. [Lab 3 - Multi-Environment Configuration](#lab-3---multi-environment-configuration)
8. [Lab 4 - Installing Argo CD](#lab-4---installing-argo-cd)
9. [Lab 5 - GitOps Deployment with Argo CD](#lab-5---gitops-deployment-with-argo-cd)
10. [Lab 6 - Upgrades and Rollbacks](#lab-6---upgrades-and-rollbacks)
11. [Lab 7 - Advanced Topics](#lab-7---advanced-topics)
12. [Interview Scenarios](#interview-scenarios)
13. [Troubleshooting](#troubleshooting)
14. [Quick Reference](#quick-reference)

---

## Lab Overview

| Topic | What You Will Learn |
|---|---|
| Reusable Helm Charts | Templating, helpers, named templates, chart best practices |
| Multi-Environment Config | Values file hierarchy, per-env overrides, secrets management |
| Argo CD GitOps | Application CRDs, sync policies, App of Apps pattern, RBAC |
| Upgrades & Rollbacks | Rolling updates, revision history, automated and manual rollback |

---

## Architecture Diagram

```
┌─────────────────────────────────────────────────────────────────────────┐
│                          Git Repository                                 │
│                                                                         │
│  helm-charts/webapp/    environments/        argocd/                    │
│  ├── Chart.yaml         ├── dev/             ├── project.yaml           │
│  ├── values.yaml        │   └── values.yaml  ├── app-of-apps.yaml      │
│  └── templates/         ├── staging/         └── apps/                  │
│      ├── deployment     │   └── values.yaml      ├── webapp-dev.yaml   │
│      ├── service        └── prod/                ├── webapp-staging.yaml│
│      ├── ingress            └── values.yaml      └── webapp-prod.yaml  │
│      ├── configmap                                                      │
│      ├── secret                                                         │
│      ├── hpa                                                            │
│      └── pvc                                                            │
└────────────────────────────┬────────────────────────────────────────────┘
                             │ git push
                             ▼
                    ┌─────────────────┐
                    │    Argo CD      │
                    │  (GitOps)       │
                    │                 │
                    │  Watches repo   │
                    │  Detects drift  │
                    │  Auto-syncs     │
                    └────────┬────────┘
                             │ helm template + kubectl apply
                             ▼
          ┌──────────────────────────────────────────┐
          │            Kubernetes Cluster             │
          │                                          │
          │  ┌──────────┐ ┌──────────┐ ┌──────────┐ │
          │  │ webapp   │ │ webapp   │ │ webapp   │ │
          │  │  -dev    │ │ -staging │ │  -prod   │ │
          │  │ (ns)     │ │ (ns)     │ │ (ns)     │ │
          │  └──────────┘ └──────────┘ └──────────┘ │
          └──────────────────────────────────────────┘
```

---

## Repository Structure

```
.
├── helm-charts/
│   └── webapp/                    # Reusable Helm chart
│       ├── Chart.yaml             # Chart metadata (name, version, description)
│       ├── values.yaml            # Default / base values
│       ├── .helmignore            # Files excluded from chart packaging
│       └── templates/
│           ├── _helpers.tpl       # Named template helpers
│           ├── deployment.yaml    # Deployment with rolling update strategy
│           ├── service.yaml       # ClusterIP / NodePort / LoadBalancer service
│           ├── ingress.yaml       # Optional Ingress (conditionally rendered)
│           ├── configmap.yaml     # Optional ConfigMap (conditionally rendered)
│           ├── secret.yaml        # Optional Secret (conditionally rendered)
│           ├── hpa.yaml           # HPA (conditionally rendered)
│           ├── pvc.yaml           # PVC (conditionally rendered)
│           ├── serviceaccount.yaml
│           └── NOTES.txt          # Post-install instructions
├── environments/
│   ├── dev/values.yaml            # Dev overrides (low resources, debug, NodePort)
│   ├── staging/values.yaml        # Staging overrides (mirrors prod, lower scale)
│   └── prod/values.yaml           # Prod overrides (HA, autoscaling, TLS, affinity)
├── argocd/
│   ├── namespace.yaml             # argocd namespace
│   ├── project.yaml               # AppProject with RBAC roles
│   ├── app-of-apps.yaml           # App-of-Apps pattern root application
│   └── apps/
│       ├── webapp-dev.yaml        # Argo CD Application for dev  (auto-sync)
│       ├── webapp-staging.yaml    # Argo CD Application for staging (auto-sync)
│       └── webapp-prod.yaml       # Argo CD Application for prod (manual sync)
├── scripts/
│   ├── helm-deploy.sh             # Deploy to any environment
│   ├── helm-rollback.sh           # Rollback to a previous revision
│   ├── helm-diff.sh               # Preview changes before deploying
│   ├── validate-chart.sh          # Lint + template all environments
│   └── promote-image.sh           # Promote image tag between environments
├── examples/
│   └── sample-app/                # Minimal Flask app with health probes
│       ├── Dockerfile
│       └── app.py
├── .github/
│   └── workflows/
│       └── helm-ci.yaml           # GitHub Actions CI pipeline
├── kind-config.yaml               # kind cluster configuration (3 nodes)
└── docs/
    └── INTERVIEW_SCENARIOS.md     # Interview Q&A and scenarios
```

---

## Prerequisites

| Tool | Minimum Version | Install |
|---|---|---|
| Docker | 20+ | https://docs.docker.com/get-docker/ |
| kubectl | 1.27+ | https://kubernetes.io/docs/tasks/tools/ |
| Helm | 3.14+ | https://helm.sh/docs/intro/install/ |
| kind | 0.20+ | https://kind.sigs.k8s.io/docs/user/quick-start/#installation |
| Argo CD CLI | 2.10+ | https://argo-cd.readthedocs.io/en/stable/cli_installation/ |
| Git | 2.30+ | https://git-scm.com/downloads |

### Installing kind

kind (Kubernetes IN Docker) runs a full Kubernetes cluster inside Docker containers. It is lightweight, fast, and ideal for local development and CI pipelines.

**Linux:**
```bash
[ $(uname -m) = x86_64 ] && curl -Lo ./kind https://kind.sigs.k8s.io/dl/v0.24.0/kind-linux-amd64
[ $(uname -m) = aarch64 ] && curl -Lo ./kind https://kind.sigs.k8s.io/dl/v0.24.0/kind-linux-arm64
chmod +x ./kind
sudo mv ./kind /usr/local/bin/kind
```

**macOS (Homebrew):**
```bash
brew install kind
```

**Windows (Chocolatey):**
```bash
choco install kind
```

### kind Cluster Configuration

This lab uses a custom kind config with 1 control-plane node and 2 worker nodes. Port mappings expose NodePort services and the Ingress controller to your host machine.

Save the following as `kind-config.yaml` in the repo root (already included in this repo):

```yaml
kind: Cluster
apiVersion: kind.x-k8s.io/v1alpha4
name: helm-argocd-lab
nodes:
  - role: control-plane
    kubeadmConfigPatches:
      - |
        kind: InitConfiguration
        nodeRegistration:
          kubeletExtraArgs:
            node-labels: "ingress-ready=true"
    extraPortMappings:
      - containerPort: 80
        hostPort: 80
        protocol: TCP
      - containerPort: 443
        hostPort: 443
        protocol: TCP
      - containerPort: 30000
        hostPort: 30000
        protocol: TCP
      - containerPort: 30001
        hostPort: 30001
        protocol: TCP
  - role: worker
  - role: worker
```

### Quick Setup (copy-paste)

```bash
# 1. Create the kind cluster
kind create cluster --config kind-config.yaml

# 2. Verify the cluster is running
kubectl cluster-info --context kind-helm-argocd-lab
kubectl get nodes
# Expected output:
#   NAME                              STATUS   ROLES           AGE   VERSION
#   helm-argocd-lab-control-plane     Ready    control-plane   ...   v1.31.x
#   helm-argocd-lab-worker            Ready    <none>          ...   v1.31.x
#   helm-argocd-lab-worker2           Ready    <none>          ...   v1.31.x

# 3. Install the NGINX Ingress Controller for kind
kubectl apply -f https://raw.githubusercontent.com/kubernetes/ingress-nginx/main/deploy/static/provider/kind/deploy.yaml

# Wait for the ingress controller to be ready
kubectl wait --namespace ingress-nginx \
  --for=condition=ready pod \
  --selector=app.kubernetes.io/component=controller \
  --timeout=120s

# 4. Verify all tools
kubectl version --client
helm version
argocd version --client
kind version
```

### Loading Local Docker Images into kind

When working with locally built images (e.g., the sample app), load them into the kind cluster instead of pushing to a registry:

```bash
# Build the sample app image
docker build -t myregistry.azurecr.io/webapp:dev-latest examples/sample-app/

# Load the image into the kind cluster
kind load docker-image myregistry.azurecr.io/webapp:dev-latest --name helm-argocd-lab

# Verify the image is available inside the cluster
docker exec -it helm-argocd-lab-control-plane crictl images | grep webapp
```

### Managing the kind Cluster

```bash
# List running kind clusters
kind get clusters

# Get the kubeconfig for a cluster
kind get kubeconfig --name helm-argocd-lab

# Delete the cluster when done
kind delete cluster --name helm-argocd-lab

# Recreate from scratch
kind create cluster --config kind-config.yaml
```

---

## Lab 1 - Helm Fundamentals

> **Goal**: Understand what Helm is, why it exists, and its core concepts.

### 1.1 What Is Helm?

Helm is the **package manager for Kubernetes**. It lets you define, install, and upgrade Kubernetes applications using a templated packaging format called **charts**.

**Key concepts**:

| Concept | Description |
|---|---|
| **Chart** | A collection of files that describe a related set of Kubernetes resources. |
| **Release** | A running instance of a chart. You can have multiple releases of the same chart. |
| **Repository** | A place where charts are stored and shared (like Docker Hub for images). |
| **Values** | Configuration that customizes a chart at install/upgrade time. |
| **Template** | Go-template files inside a chart that produce valid Kubernetes YAML. |

### 1.2 Helm CLI Essentials

```bash
# Search for charts in a repo
helm search repo nginx

# Add a public repository
helm repo add bitnami https://charts.bitnami.com/bitnami
helm repo update

# Install a chart
helm install my-nginx bitnami/nginx --namespace demo --create-namespace

# List releases
helm list -A

# Check release status
helm status my-nginx -n demo

# View release history (revisions)
helm history my-nginx -n demo

# Upgrade a release with new values
helm upgrade my-nginx bitnami/nginx -n demo --set replicaCount=3

# Rollback to the previous revision
helm rollback my-nginx 1 -n demo

# Uninstall
helm uninstall my-nginx -n demo

# Render templates locally without deploying
helm template my-nginx bitnami/nginx -n demo
```

### 1.3 Hands-On Exercise

```bash
# 1. Add the bitnami repo and install nginx
helm repo add bitnami https://charts.bitnami.com/bitnami
helm install lab1-nginx bitnami/nginx --namespace lab1 --create-namespace

# 2. Verify the pod is running
kubectl get pods -n lab1

# 3. Upgrade to 3 replicas
helm upgrade lab1-nginx bitnami/nginx -n lab1 --set replicaCount=3

# 4. Confirm 3 pods are running
kubectl get pods -n lab1

# 5. Check history
helm history lab1-nginx -n lab1

# 6. Rollback
helm rollback lab1-nginx 1 -n lab1

# 7. Clean up
helm uninstall lab1-nginx -n lab1
kubectl delete namespace lab1
```

---

## Lab 2 - Building a Reusable Helm Chart

> **Goal**: Build the webapp chart from scratch and understand every file.

### 2.1 Chart Anatomy

```bash
# Examine the chart
tree helm-charts/webapp/
```

**Chart.yaml** — The chart's identity card:

```yaml
apiVersion: v2
name: webapp
description: A reusable Helm chart for deploying web applications
type: application
version: 1.0.0        # Chart version (bump on chart changes)
appVersion: "1.0.0"   # Application version (the software you're deploying)
```

- `version` is the chart's semver; increment it when you change templates or defaults.
- `appVersion` tracks the application being deployed.

### 2.2 Understanding the Template Helper `_helpers.tpl`

Named templates live in `_helpers.tpl` and are reused across all resource files:

```yaml
# Generates consistent labels on every resource
{{- define "webapp.labels" -}}
helm.sh/chart: {{ include "webapp.chart" . }}
{{ include "webapp.selectorLabels" . }}
app.kubernetes.io/version: {{ .Chart.AppVersion | quote }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
{{- end }}
```

**Why this matters**: Every resource gets the same set of labels, making it trivial to query (`kubectl get all -l app.kubernetes.io/name=webapp`).

### 2.3 Deployment Template Deep Dive

Key patterns used in `templates/deployment.yaml`:

| Pattern | Purpose |
|---|---|
| `{{- if not .Values.autoscaling.enabled }}` | Omit `replicas` when HPA manages scaling |
| `checksum/config` annotation | Force pod restart when ConfigMap changes |
| `{{- with .Values.env }}` | Conditionally render env vars |
| `{{- toYaml . \| nindent 12 }}` | Serialize YAML at the correct indentation |

### 2.4 Hands-On: Render and Inspect

```bash
# Render with default values
helm template my-webapp helm-charts/webapp/ --namespace test

# Render with dev overrides
helm template my-webapp helm-charts/webapp/ \
  -f environments/dev/values.yaml --namespace webapp-dev

# Save to a file for inspection
helm template my-webapp helm-charts/webapp/ \
  -f environments/prod/values.yaml --namespace webapp-prod > /tmp/prod-manifests.yaml

# Count the resources
grep '^kind:' /tmp/prod-manifests.yaml
```

### 2.5 Lint the Chart

```bash
helm lint helm-charts/webapp/
helm lint helm-charts/webapp/ -f environments/dev/values.yaml
helm lint helm-charts/webapp/ -f environments/staging/values.yaml
helm lint helm-charts/webapp/ -f environments/prod/values.yaml

# Or use the validation script
./scripts/validate-chart.sh
```

---

## Lab 3 - Multi-Environment Configuration

> **Goal**: Use values files to maintain dev, staging, and production configurations from a single chart.

### 3.1 The Values Hierarchy

Helm merges values in this order (last wins):

```
1. helm-charts/webapp/values.yaml          (base defaults)
2. environments/<env>/values.yaml           (environment override)
3. --set / --set-string CLI flags           (highest priority)
```

### 3.2 Comparing Environments

| Setting | Dev | Staging | Prod |
|---|---|---|---|
| `replicaCount` | 1 | 2 | 3 |
| `image.tag` | dev-latest | staging-latest | 1.0.0 (pinned) |
| `image.pullPolicy` | Always | IfNotPresent | IfNotPresent |
| `resources.requests.cpu` | 50m | 100m | 250m |
| `resources.limits.memory` | 128Mi | 256Mi | 512Mi |
| `autoscaling.enabled` | false | true (2-5) | true (3-20) |
| `ingress.tls` | none | staging cert | prod cert |
| `configMap.LOG_LEVEL` | debug | info | warn |
| `persistence.enabled` | false | true (5Gi) | true (20Gi) |
| `strategy.maxUnavailable` | 1 | 0 | 0 |

### 3.3 Hands-On: Deploy to Dev

```bash
# Install into the dev namespace
helm upgrade --install webapp-dev helm-charts/webapp/ \
  -f environments/dev/values.yaml \
  --namespace webapp-dev \
  --create-namespace

# Verify
kubectl get all -n webapp-dev
kubectl describe deployment webapp-dev -n webapp-dev

# Check the ConfigMap
kubectl get configmap webapp-dev -n webapp-dev -o yaml

# Port-forward and test
kubectl port-forward svc/webapp-dev 8080:80 -n webapp-dev &
curl http://localhost:8080/
curl http://localhost:8080/healthz
```

### 3.4 Hands-On: Deploy to Staging

```bash
helm upgrade --install webapp-staging helm-charts/webapp/ \
  -f environments/staging/values.yaml \
  --namespace webapp-staging \
  --create-namespace

# Note the differences
kubectl get deployment webapp-staging -n webapp-staging -o yaml | grep replicas
kubectl get hpa -n webapp-staging
kubectl get pvc -n webapp-staging
kubectl get ingress -n webapp-staging
```

### 3.5 Hands-On: Deploy to Production

```bash
helm upgrade --install webapp-prod helm-charts/webapp/ \
  -f environments/prod/values.yaml \
  --namespace webapp-prod \
  --create-namespace

# Observe production-grade settings
kubectl get deployment webapp-prod -n webapp-prod -o yaml | grep -A5 strategy
kubectl get hpa -n webapp-prod
kubectl get ingress webapp-prod -n webapp-prod -o yaml | grep tls -A5
```

### 3.6 Using the Deploy Script

```bash
# Dry run (template only)
./scripts/helm-deploy.sh dev --dry-run

# Deploy to dev
./scripts/helm-deploy.sh dev

# Deploy to staging
./scripts/helm-deploy.sh staging

# Deploy to prod (requires confirmation)
./scripts/helm-deploy.sh prod
```

---

## Lab 4 - Installing Argo CD

> **Goal**: Install Argo CD in your kind cluster and access the dashboard.

### 4.1 Verify Your kind Cluster

```bash
# Confirm the kind cluster is running and you have the right context
kubectl cluster-info --context kind-helm-argocd-lab

# Verify all nodes are Ready
kubectl get nodes
# Expected: 1 control-plane + 2 workers

# Check available resources
kubectl top nodes 2>/dev/null || echo "Metrics server not installed (optional)"
```

### 4.2 Install Argo CD

```bash
# Create the namespace
kubectl apply -f argocd/namespace.yaml

# Install Argo CD
kubectl apply -n argocd \
  -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml

# Wait for all Argo CD pods to be ready (this may take 1-2 minutes on kind)
kubectl wait --for=condition=ready pod --all -n argocd --timeout=300s

# Verify all components are running
kubectl get pods -n argocd
# Expected pods:
#   argocd-application-controller-0
#   argocd-dex-server-...
#   argocd-notifications-controller-...
#   argocd-redis-...
#   argocd-repo-server-...
#   argocd-server-...
```

### 4.3 Access the Argo CD UI

```bash
# Port-forward the Argo CD server
kubectl port-forward svc/argocd-server -n argocd 8443:443 &

# Get the initial admin password
ARGOCD_PASSWORD=$(kubectl -n argocd get secret argocd-initial-admin-secret \
  -o jsonpath="{.data.password}" | base64 --decode)
echo "Argo CD admin password: ${ARGOCD_PASSWORD}"

# Login with the CLI
argocd login localhost:8443 \
  --username admin \
  --password "${ARGOCD_PASSWORD}" \
  --insecure
```

Open https://localhost:8443 in your browser and log in with `admin` / `<password>`.

> **kind tip**: If port 8443 conflicts with another service, use a different host port:
> `kubectl port-forward svc/argocd-server -n argocd 9443:443 &`

### 4.4 Register Your Git Repository

```bash
# If using HTTPS with credentials
argocd repo add https://github.com/YOUR_ORG/helm-argo-cd-gitops.git \
  --username <user> --password <token>

# If using SSH
argocd repo add git@github.com:YOUR_ORG/helm-argo-cd-gitops.git \
  --ssh-private-key-path ~/.ssh/id_rsa
```

### 4.5 Create the AppProject

```bash
kubectl apply -f argocd/project.yaml
argocd proj list
```

### 4.6 kind-Specific Considerations

| Topic | Detail |
|---|---|
| **Image loading** | kind clusters cannot pull from local Docker. Use `kind load docker-image <image> --name helm-argocd-lab` to make images available. |
| **Ingress** | The NGINX Ingress Controller installed in the prerequisites routes traffic through the control-plane node's port mappings (80/443 on localhost). |
| **Persistence** | kind uses `standard` StorageClass backed by `rancher.io/local-path`. PVCs work out of the box. |
| **Resources** | kind shares your host's Docker resources. If pods are Pending, check Docker's memory allocation (recommend 8 GB+). |
| **Multiple clusters** | You can run multiple kind clusters simultaneously. Use `kubectl config use-context kind-<name>` to switch. |

---

## Lab 5 - GitOps Deployment with Argo CD

> **Goal**: Deploy the webapp across all environments using Argo CD's GitOps model.

### 5.1 Understanding Argo CD Application CRD

An Argo CD `Application` has three key sections:

```yaml
spec:
  source:       # WHERE to get the manifests (git repo + path + values)
  destination:  # WHERE to deploy (cluster + namespace)
  syncPolicy:   # HOW to keep in sync (auto/manual, prune, selfHeal)
```

### 5.2 Sync Policies Explained

| Policy | Dev | Staging | Prod |
|---|---|---|---|
| **Automated sync** | Yes | Yes | **No** (manual) |
| **Self-heal** | Yes | Yes | No |
| **Prune** | Yes | Yes | No (manual) |
| **Retry** | 3 attempts | 5 attempts | 3 attempts |

Production uses **manual sync** to prevent accidental changes and enforce review gates.

### 5.3 Deploy Using the App-of-Apps Pattern

The App-of-Apps pattern uses a single "root" Application that manages all other Applications:

```bash
# Apply the root Application
kubectl apply -f argocd/app-of-apps.yaml

# Argo CD will now discover and create all child Applications
argocd app list
```

This automatically creates `webapp-dev`, `webapp-staging`, and `webapp-prod`.

### 5.4 Deploy Environments Individually (Alternative)

```bash
# Dev (auto-syncs immediately)
kubectl apply -f argocd/apps/webapp-dev.yaml

# Staging
kubectl apply -f argocd/apps/webapp-staging.yaml

# Production (requires manual sync)
kubectl apply -f argocd/apps/webapp-prod.yaml
```

### 5.5 Verify Deployments

```bash
# Check all applications
argocd app list

# Get detailed info for each
argocd app get webapp-dev
argocd app get webapp-staging
argocd app get webapp-prod

# View the sync status
argocd app get webapp-dev -o json | jq '.status.sync.status'
```

### 5.6 Trigger a GitOps Deployment

This is the core GitOps workflow — the only thing you touch is Git:

```bash
# 1. Edit the dev values (e.g., change LOG_LEVEL)
# Edit environments/dev/values.yaml -> change LOG_LEVEL to "info"

# 2. Commit and push
git add environments/dev/values.yaml
git commit -m "chore(dev): change LOG_LEVEL to info"
git push

# 3. Argo CD detects the change and auto-syncs within ~3 minutes
#    (or trigger manually)
argocd app sync webapp-dev

# 4. Observe the rollout
argocd app get webapp-dev
kubectl rollout status deployment/webapp-dev -n webapp-dev
```

### 5.7 Manual Sync for Production

```bash
# Check what's out of sync
argocd app diff webapp-prod

# Sync with prune
argocd app sync webapp-prod --prune

# Monitor
argocd app get webapp-prod --refresh
```

---

## Lab 6 - Upgrades and Rollbacks

> **Goal**: Perform rolling upgrades, inspect history, and rollback failed deployments.

### 6.1 Performing a Rolling Upgrade

```bash
# Upgrade the image tag in dev
# Edit environments/dev/values.yaml: image.tag -> "dev-v2"
# Then push to Git (Argo CD auto-syncs)

# OR use Helm directly:
helm upgrade webapp-dev helm-charts/webapp/ \
  -f environments/dev/values.yaml \
  --set image.tag="dev-v2" \
  --namespace webapp-dev

# Watch the rolling update
kubectl rollout status deployment/webapp-dev -n webapp-dev

# Verify the new pods
kubectl get pods -n webapp-dev -o wide
```

### 6.2 Inspecting Release History

```bash
# Helm history shows every revision
helm history webapp-dev -n webapp-dev

# Output example:
# REVISION  STATUS      CHART          APP VERSION  DESCRIPTION
# 1         superseded  webapp-1.0.0   1.0.0        Install complete
# 2         deployed    webapp-1.0.0   1.0.0        Upgrade complete
```

### 6.3 Rolling Back with Helm

```bash
# Rollback to the previous revision
helm rollback webapp-dev -n webapp-dev

# Rollback to a specific revision
helm rollback webapp-dev 1 -n webapp-dev

# Confirm
helm history webapp-dev -n webapp-dev
kubectl get pods -n webapp-dev
```

### 6.4 Rolling Back with Argo CD

```bash
# View the history
argocd app history webapp-dev

# Rollback to a previous revision
argocd app rollback webapp-dev <ID>

# IMPORTANT: Argo CD rollback is temporary.
# The next sync cycle will re-apply the Git state.
# For a permanent rollback, revert the commit in Git.
```

### 6.5 Permanent Rollback (GitOps Way)

```bash
# Find the commit to revert
git log --oneline -5

# Revert the bad commit
git revert <commit-hash>
git push

# Argo CD detects the revert and syncs to the reverted state
argocd app sync webapp-dev
```

### 6.6 Using the Scripts

```bash
# Deploy
./scripts/helm-deploy.sh dev

# Preview changes before deploying
./scripts/helm-diff.sh staging

# Rollback
./scripts/helm-rollback.sh dev
./scripts/helm-rollback.sh dev 2   # specific revision

# Promote an image from dev to staging
./scripts/promote-image.sh dev staging
```

### 6.7 Simulating a Failed Deployment

```bash
# Deploy a broken image
helm upgrade webapp-dev helm-charts/webapp/ \
  -f environments/dev/values.yaml \
  --set image.tag="nonexistent-tag" \
  --namespace webapp-dev

# Watch the failure
kubectl get pods -n webapp-dev
kubectl describe pod -l app.kubernetes.io/name=webapp -n webapp-dev

# Rollback
helm rollback webapp-dev -n webapp-dev
kubectl get pods -n webapp-dev
```

---

## Lab 7 - Advanced Topics

### 7.1 Helm Hooks

Hooks let you run Jobs at specific lifecycle points:

```yaml
# Example: pre-upgrade database migration
apiVersion: batch/v1
kind: Job
metadata:
  name: db-migrate
  annotations:
    "helm.sh/hook": pre-upgrade
    "helm.sh/hook-weight": "0"
    "helm.sh/hook-delete-policy": hook-succeeded
spec:
  template:
    spec:
      containers:
        - name: migrate
          image: myregistry.azurecr.io/webapp:1.0.0
          command: ["python", "manage.py", "migrate"]
      restartPolicy: Never
```

### 7.2 Helm Tests

```yaml
# templates/tests/test-connection.yaml
apiVersion: v1
kind: Pod
metadata:
  name: "{{ include "webapp.fullname" . }}-test"
  annotations:
    "helm.sh/hook": test
spec:
  containers:
    - name: wget
      image: busybox
      command: ['wget']
      args: ['{{ include "webapp.fullname" . }}:{{ .Values.service.port }}']
  restartPolicy: Never
```

Run the test:

```bash
helm test webapp-dev -n webapp-dev
```

### 7.3 Sealed Secrets (Production-Grade Secrets)

Never commit plain-text secrets. Use Sealed Secrets:

```bash
# Install kubeseal
brew install kubeseal

# Seal a secret
kubectl create secret generic webapp-prod \
  --from-literal=DB_PASSWORD=real-password \
  --dry-run=client -o yaml | \
  kubeseal --format yaml > environments/prod/sealed-secret.yaml

# Commit the sealed secret (safe to store in Git)
git add environments/prod/sealed-secret.yaml
git commit -m "feat: add sealed secret for prod"
git push
```

### 7.4 Chart Versioning and Packaging

```bash
# Package the chart
helm package helm-charts/webapp/

# Push to an OCI registry
helm push webapp-1.0.0.tgz oci://myregistry.azurecr.io/helm

# Use the OCI chart in Argo CD
# source.chart: webapp
# source.repoURL: myregistry.azurecr.io/helm
# source.targetRevision: 1.0.0
```

---

## Interview Scenarios

> See the complete interview preparation guide at [docs/INTERVIEW_SCENARIOS.md](docs/INTERVIEW_SCENARIOS.md).

### Quick Preview

| # | Scenario | Key Points |
|---|---|---|
| 1 | Explain your Helm chart structure | Chart.yaml, values.yaml, templates, _helpers.tpl, NOTES.txt |
| 2 | How do you manage multiple environments? | Single chart + per-env values files + values merge order |
| 3 | What is GitOps and how does Argo CD implement it? | Single source of truth in Git, pull-based reconciliation |
| 4 | How do you handle rollbacks? | `helm rollback`, `git revert` + Argo CD sync, revision history |
| 5 | How do you secure secrets in GitOps? | Sealed Secrets, External Secrets Operator, Vault |
| 6 | Describe the App-of-Apps pattern | A root Application that manages child Applications |
| 7 | How does Argo CD self-heal? | Detects drift from Git state and re-applies desired state |

---

## Troubleshooting

### Helm Issues

```bash
# Template rendering errors
helm template my-release helm-charts/webapp/ --debug

# Detailed install/upgrade errors
helm upgrade --install my-release helm-charts/webapp/ --debug --dry-run

# Check pending releases
helm list -A --pending

# Force-delete a stuck release
helm uninstall <release-name> -n <namespace> --no-hooks
```

### Argo CD Issues

```bash
# Application stuck in "Progressing"
argocd app get <app-name> --refresh
kubectl describe deployment <name> -n <namespace>

# Sync failed
argocd app get <app-name> -o json | jq '.status.conditions'

# Repository not accessible
argocd repo list
argocd repo get <repo-url>

# Hard refresh
argocd app get <app-name> --hard-refresh
```

### Kubernetes Issues

```bash
# Pod crash loop
kubectl logs <pod-name> -n <namespace> --previous
kubectl describe pod <pod-name> -n <namespace>

# ImagePullBackOff
kubectl describe pod <pod-name> -n <namespace> | grep -A5 Events
```

### kind-Specific Issues

```bash
# Cluster won't start — check Docker is running
docker ps
# If Docker daemon is not running, start it first

# Cluster won't start — port conflict (80/443 already in use)
# Check what's using the ports
sudo lsof -i :80
sudo lsof -i :443
# Stop the conflicting service, or edit kind-config.yaml to use different host ports

# Pods stuck in Pending — insufficient resources
# Check Docker resource allocation
docker stats --no-stream
# Increase Docker memory to at least 8 GB (Docker Desktop > Settings > Resources)

# Image not found inside kind cluster
# kind cannot pull from the local Docker daemon by default
kind load docker-image <image>:<tag> --name helm-argocd-lab

# Check images available inside the kind cluster
docker exec -it helm-argocd-lab-control-plane crictl images

# Node not Ready
kubectl describe node helm-argocd-lab-control-plane
# Common cause: Docker running out of disk space
docker system prune -a

# Ingress not working — verify NGINX controller is running
kubectl get pods -n ingress-nginx
kubectl logs -n ingress-nginx -l app.kubernetes.io/component=controller

# DNS resolution issues inside pods
kubectl run dnsutils --image=registry.k8s.io/e2e-test-images/jessie-dnsutils:1.3 \
  --restart=Never -- sleep 3600
kubectl exec dnsutils -- nslookup kubernetes.default
kubectl delete pod dnsutils

# Reset the cluster completely
kind delete cluster --name helm-argocd-lab
kind create cluster --config kind-config.yaml
```

---

## Quick Reference

### Helm Commands Cheat Sheet

```bash
helm repo add <name> <url>          # Add a chart repository
helm repo update                     # Refresh repositories
helm search repo <keyword>           # Search charts
helm install <release> <chart>       # Install a chart
helm upgrade --install <rel> <chart> # Install or upgrade
helm list -A                         # List all releases
helm history <release>               # Show release history
helm rollback <release> <revision>   # Rollback to a revision
helm uninstall <release>             # Remove a release
helm template <release> <chart>      # Render templates locally
helm lint <chart-path>               # Validate chart syntax
helm package <chart-path>            # Package chart as .tgz
helm test <release>                  # Run chart tests
```

### Argo CD Commands Cheat Sheet

```bash
argocd login <server>                # Authenticate
argocd app list                      # List all applications
argocd app get <name>                # Get app details
argocd app sync <name>               # Trigger a sync
argocd app diff <name>               # Show diff from Git
argocd app history <name>            # Show sync history
argocd app rollback <name> <id>      # Rollback to a sync ID
argocd app delete <name>             # Delete an application
argocd proj list                     # List projects
argocd repo list                     # List connected repos
```

### kind Commands Cheat Sheet

```bash
kind create cluster --config <file>                # Create cluster from config
kind create cluster --name <name>                  # Create cluster with default settings
kind get clusters                                  # List all kind clusters
kind get kubeconfig --name <name>                  # Export kubeconfig
kind get nodes --name <name>                       # List cluster nodes
kind load docker-image <img> --name <name>         # Load image into cluster
kind load image-archive <tar> --name <name>        # Load image from tar archive
kind delete cluster --name <name>                  # Delete a cluster
kind delete clusters --all                         # Delete all clusters
kind export logs --name <name> /tmp/kind-logs      # Export cluster logs for debugging
kind version                                       # Print kind version
```

---

## Full Lab Cleanup

When you are done with the lab, clean up all resources:

```bash
# 1. Uninstall all Helm releases
helm uninstall webapp-dev -n webapp-dev 2>/dev/null
helm uninstall webapp-staging -n webapp-staging 2>/dev/null
helm uninstall webapp-prod -n webapp-prod 2>/dev/null

# 2. Delete the Argo CD Applications
kubectl delete -f argocd/app-of-apps.yaml 2>/dev/null
kubectl delete -f argocd/apps/ 2>/dev/null
kubectl delete -f argocd/project.yaml 2>/dev/null

# 3. Delete the kind cluster (removes everything)
kind delete cluster --name helm-argocd-lab

# 4. Verify no clusters remain
kind get clusters
docker ps   # No kind containers should be running
```

---

## License

This lab is provided for educational purposes. Feel free to use and adapt it for your learning and training needs.
