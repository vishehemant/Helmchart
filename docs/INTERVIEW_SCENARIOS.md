# Helm + Argo CD + GitOps — Interview Scenarios & Questions

This document contains **50+ interview questions and scenarios** organized by difficulty. Each answer includes the technical depth expected in a real DevOps/SRE/Platform Engineering interview.

---

## Table of Contents

1. [Helm — Fundamentals (Beginner)](#helm--fundamentals-beginner)
2. [Helm — Intermediate](#helm--intermediate)
3. [Helm — Advanced](#helm--advanced)
4. [Argo CD & GitOps — Fundamentals](#argo-cd--gitops--fundamentals)
5. [Argo CD — Intermediate](#argo-cd--intermediate)
6. [Argo CD — Advanced](#argo-cd--advanced)
7. [Scenario-Based Questions](#scenario-based-questions)
8. [Architecture & Design Questions](#architecture--design-questions)
9. [Troubleshooting Scenarios](#troubleshooting-scenarios)
10. [Rapid-Fire / One-Liner Answers](#rapid-fire--one-liner-answers)

---

## Helm — Fundamentals (Beginner)

### Q1: What is Helm and why do we need it?

**Answer:**
Helm is a package manager for Kubernetes. Without Helm, you would need to write and maintain individual YAML files for every Kubernetes resource (Deployment, Service, ConfigMap, etc.) and manually keep them consistent across environments.

Helm solves this by:
- **Templating**: Write YAML once with variables; render for any environment.
- **Packaging**: Bundle related resources into a single deployable unit (chart).
- **Versioning**: Track chart versions and application versions independently.
- **Release Management**: Install, upgrade, rollback, and uninstall as atomic operations.
- **Reusability**: The same chart can be used across dev, staging, and prod by swapping values files.

---

### Q2: Explain the difference between `Chart.yaml` and `values.yaml`.

**Answer:**

| File | Purpose |
|---|---|
| `Chart.yaml` | Metadata about the chart itself — name, version, description, dependencies. It is the chart's identity card. |
| `values.yaml` | Default configuration for the chart. Users override these values per environment or at install time using `-f` or `--set`. |

`Chart.yaml` is static and changes only when the chart version is bumped. `values.yaml` is the primary mechanism for customization.

---

### Q3: What is the difference between `helm install` and `helm upgrade --install`?

**Answer:**
- `helm install` creates a **new** release. It fails if a release with the same name already exists.
- `helm upgrade --install` is **idempotent**: it upgrades the release if it exists, or installs it if it doesn't.

In CI/CD pipelines and automation, always use `helm upgrade --install` because it handles both the first deploy and all subsequent updates.

---

### Q4: What is a Helm release?

**Answer:**
A release is a **running instance** of a chart in a cluster. Each release has:
- A unique name (e.g., `webapp-dev`)
- A namespace
- A revision history (revision 1, 2, 3, etc.)
- A status (deployed, failed, pending-upgrade, etc.)

You can have multiple releases of the same chart (e.g., `webapp-dev` and `webapp-prod`) with different configurations.

---

### Q5: What is the purpose of `_helpers.tpl`?

**Answer:**
`_helpers.tpl` contains **named templates** (also called partials or sub-templates) that are reused across multiple template files. Common helpers include:
- `webapp.fullname` — generates a consistent resource name
- `webapp.labels` — produces standard labels for every resource
- `webapp.selectorLabels` — labels used in `matchLabels` selectors

They follow the DRY principle and ensure consistency. The leading underscore tells Helm not to render this file as a standalone manifest.

---

### Q6: How does Helm handle template rendering?

**Answer:**
Helm uses Go's `text/template` engine. The rendering flow:

1. Helm reads `Chart.yaml` and `values.yaml`.
2. User-provided values (`-f` files, `--set` flags) are merged on top of defaults.
3. Templates in `templates/` are executed with the merged values as context.
4. The rendered YAML is validated and sent to the Kubernetes API server.

Key objects available in templates:
- `.Values` — the merged values
- `.Release` — release metadata (name, namespace, revision)
- `.Chart` — chart metadata from `Chart.yaml`
- `.Template` — current template info

---

## Helm — Intermediate

### Q7: How do you manage multiple environments with a single Helm chart?

**Answer:**
Use **environment-specific values files**:

```
environments/
├── dev/values.yaml
├── staging/values.yaml
└── prod/values.yaml
```

Deploy with:
```bash
helm upgrade --install webapp-dev ./helm-charts/webapp -f environments/dev/values.yaml
helm upgrade --install webapp-prod ./helm-charts/webapp -f environments/prod/values.yaml
```

The base `values.yaml` in the chart contains sane defaults. Each environment file overrides only what differs (replicas, resources, image tags, feature flags, etc.).

**Key benefit**: One chart, one set of templates, multiple configurations. Changes to the chart structure automatically apply to all environments.

---

### Q8: Explain the Helm values merge order.

**Answer:**
Values are merged in this priority order (last wins):

1. `helm-charts/webapp/values.yaml` (chart defaults — lowest priority)
2. First `-f` file
3. Second `-f` file (overrides the first)
4. `--set` flags (highest priority)

Example:
```bash
helm upgrade --install my-release ./chart \
  -f values-base.yaml \
  -f values-prod.yaml \
  --set image.tag=v2.0.0
```

Here `image.tag=v2.0.0` wins over anything in the YAML files.

---

### Q9: What is the `checksum/config` annotation pattern and why is it used?

**Answer:**
```yaml
annotations:
  checksum/config: {{ include (print $.Template.BasePath "/configmap.yaml") . | sha256sum }}
```

This forces a pod restart when the ConfigMap content changes. Without this, changing a ConfigMap does NOT trigger a Deployment rollout because the Deployment spec itself hasn't changed. The checksum annotation changes whenever the ConfigMap data changes, which in turn changes the pod template spec, triggering a rolling update.

---

### Q10: How does Helm handle rollbacks?

**Answer:**
Every `helm upgrade` creates a new **revision**. Helm stores the complete rendered manifests for each revision as a Secret in the release namespace.

```bash
helm history webapp-dev -n webapp-dev
# Shows all revisions with status and description

helm rollback webapp-dev 2 -n webapp-dev
# Restores revision 2 as a NEW revision (e.g., revision 4)
```

A rollback does NOT delete the failed revision. It creates a new revision that replicates the state of the target revision. The revision history remains intact for auditing.

---

### Q11: What are Helm hooks? Give an example.

**Answer:**
Hooks are resources annotated with `helm.sh/hook` that run at specific lifecycle points:

| Hook | When it runs |
|---|---|
| `pre-install` | Before any chart resources are installed |
| `post-install` | After all chart resources are installed |
| `pre-upgrade` | Before an upgrade |
| `post-upgrade` | After an upgrade |
| `pre-delete` | Before a release is deleted |
| `pre-rollback` | Before a rollback |
| `test` | When `helm test` is run |

Common use case — database migration before upgrade:

```yaml
annotations:
  "helm.sh/hook": pre-upgrade
  "helm.sh/hook-weight": "0"
  "helm.sh/hook-delete-policy": hook-succeeded
```

---

### Q12: How do you conditionally render resources in Helm?

**Answer:**
Use `if` blocks:

```yaml
{{- if .Values.ingress.enabled -}}
apiVersion: networking.k8s.io/v1
kind: Ingress
...
{{- end }}
```

This means the Ingress resource is only created when `ingress.enabled: true` in the values. This pattern is used throughout the chart for optional features like autoscaling, persistence, ConfigMaps, and Secrets.

---

## Helm — Advanced

### Q13: How do you handle sensitive data in Helm charts?

**Answer:**
Several approaches, from least to most secure:

1. **Helm Secrets plugin** (`helm-secrets`): Encrypts values files using SOPS/GPG before committing to Git.
2. **Sealed Secrets**: Encrypt secrets client-side; only the controller in the cluster can decrypt.
3. **External Secrets Operator**: Syncs secrets from AWS Secrets Manager, HashiCorp Vault, Azure Key Vault, etc.
4. **`--set` flags in CI/CD**: Pass secrets from a vault at deploy time; never commit them.

Never store plain-text secrets in Git, even in private repositories.

---

### Q14: Explain Helm chart dependencies and the `charts/` directory.

**Answer:**
A chart can declare dependencies in `Chart.yaml`:

```yaml
dependencies:
  - name: postgresql
    version: "12.x.x"
    repository: "https://charts.bitnami.com/bitnami"
    condition: postgresql.enabled
```

`helm dependency update` downloads them into `charts/`. During rendering, dependent charts are rendered alongside the parent chart. The `condition` field lets you toggle them on/off per environment.

---

### Q15: What is the difference between `helm template` and `helm install --dry-run`?

**Answer:**

| Feature | `helm template` | `helm install --dry-run` |
|---|---|---|
| Needs cluster connection | No | Yes |
| Server-side validation | No | Yes |
| Shows NOTES.txt | Yes | Yes |
| Evaluates capabilities | Uses defaults | Uses actual cluster |
| Use case | CI validation, offline rendering | Pre-deploy validation |

`helm template` is preferred in CI pipelines because it doesn't require cluster access.

---

### Q16: How do you version your Helm charts?

**Answer:**
Follow Semantic Versioning (semver):

- **Major** (2.0.0): Breaking changes to values schema
- **Minor** (1.1.0): New features (new template, new value), backward compatible
- **Patch** (1.0.1): Bug fixes in templates

`appVersion` tracks the application software version separately. You might bump the chart version without changing the app version (e.g., fixing a template bug).

---

## Argo CD & GitOps — Fundamentals

### Q17: What is GitOps?

**Answer:**
GitOps is an operational framework where:

1. **Git is the single source of truth** for both infrastructure and application configuration.
2. **Desired state** is declared in Git (Kubernetes manifests, Helm charts, Kustomize overlays).
3. An **operator/controller** (like Argo CD) continuously reconciles the cluster state to match Git.
4. All changes go through **pull requests** — providing audit trails, reviews, and rollback via `git revert`.

GitOps = Infrastructure as Code + Merge Requests + CI/CD + Continuous Reconciliation.

---

### Q18: How does Argo CD work?

**Answer:**
Argo CD is a declarative, GitOps-based continuous delivery tool for Kubernetes.

**Architecture:**
- **API Server**: Exposes the REST/gRPC API and UI.
- **Repository Server**: Clones Git repos, renders Helm/Kustomize manifests.
- **Application Controller**: Watches Applications, compares desired (Git) vs. live (cluster) state, and syncs.

**Workflow:**
1. You define an `Application` CRD pointing to a Git path and a cluster namespace.
2. The controller polls Git (default: every 3 minutes) or receives a webhook.
3. It renders the manifests (Helm template, Kustomize build, or plain YAML).
4. It compares the rendered manifests with the live cluster state.
5. If out of sync, it either auto-syncs or waits for manual approval (based on policy).

---

### Q19: What is the difference between push-based and pull-based CD?

**Answer:**

| Aspect | Push-based (e.g., Jenkins) | Pull-based (e.g., Argo CD) |
|---|---|---|
| **Who deploys** | CI server pushes to the cluster | Agent inside the cluster pulls from Git |
| **Credentials** | CI needs cluster credentials | Only the agent needs cluster access |
| **Drift detection** | None (fire and forget) | Continuous reconciliation |
| **Security** | Cluster credentials outside the cluster | Credentials stay inside the cluster |
| **Recovery** | Manual re-run needed | Automatic self-healing |

Argo CD uses the **pull model**: it lives inside the cluster and pulls desired state from Git.

---

### Q20: What is an Argo CD Application?

**Answer:**
An `Application` is a Kubernetes Custom Resource that tells Argo CD:
- **source**: Where to find manifests (repo URL, path, branch/tag, Helm values)
- **destination**: Where to deploy (cluster server URL, namespace)
- **syncPolicy**: How to keep in sync (automated/manual, prune, selfHeal, retry)

Example:
```yaml
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: webapp-dev
  namespace: argocd
spec:
  source:
    repoURL: https://github.com/org/repo.git
    path: helm-charts/webapp
    helm:
      valueFiles:
        - ../../environments/dev/values.yaml
  destination:
    server: https://kubernetes.default.svc
    namespace: webapp-dev
  syncPolicy:
    automated:
      prune: true
      selfHeal: true
```

---

## Argo CD — Intermediate

### Q21: Explain Argo CD sync policies: automated, prune, and selfHeal.

**Answer:**

| Policy | What it does |
|---|---|
| `automated` | Automatically syncs when Git changes are detected (no manual trigger needed). |
| `prune` | Deletes resources from the cluster that no longer exist in Git. Without this, orphaned resources remain. |
| `selfHeal` | Reverts manual changes (kubectl edits, emergency patches) back to the Git-declared state. |

**Recommended settings by environment:**
- **Dev**: automated + prune + selfHeal (fast iteration)
- **Staging**: automated + prune + selfHeal (mirrors prod behavior)
- **Prod**: Manual sync only (require explicit approval before deploying)

---

### Q22: What is the App-of-Apps pattern?

**Answer:**
A pattern where a single "root" Application manages a directory of child Application manifests:

```
argocd/
├── app-of-apps.yaml         # Root Application points to argocd/apps/
└── apps/
    ├── webapp-dev.yaml       # Child Application
    ├── webapp-staging.yaml   # Child Application
    └── webapp-prod.yaml      # Child Application
```

**Benefits:**
- Adding a new environment = adding a new YAML file and pushing to Git.
- All Applications are version-controlled and auditable.
- The root Application auto-discovers and creates child Applications.
- Deleting the root Application can cascade-delete all children.

---

### Q23: How does Argo CD handle Helm charts?

**Answer:**
Argo CD's **Repository Server** renders Helm charts during sync:

1. It clones the Git repo.
2. It runs `helm template` (NOT `helm install`) with the specified values files and parameters.
3. The rendered manifests are compared against the live cluster state.
4. Differences are applied using `kubectl apply`.

This means Helm releases are NOT created in the traditional sense. Argo CD manages the lifecycle, not Helm's release tracking. You cannot use `helm list` to see Argo CD-managed releases.

---

### Q24: What is an AppProject and why is it important?

**Answer:**
An `AppProject` restricts what an Application can do:

- **sourceRepos**: Which Git repos are allowed.
- **destinations**: Which clusters and namespaces are allowed.
- **clusterResourceWhitelist**: Which cluster-scoped resources can be created.
- **roles**: RBAC within the project.

This implements the principle of least privilege. For example, a dev team's project only allows deployments to dev/staging namespaces, preventing accidental production changes.

---

### Q25: How do you handle secrets in a GitOps workflow with Argo CD?

**Answer:**
Since GitOps requires everything in Git, secrets need special treatment:

1. **Sealed Secrets**: Encrypt secrets with a public key; only the cluster controller can decrypt.
2. **External Secrets Operator (ESO)**: Creates Kubernetes Secrets from external sources (Vault, AWS SM).
3. **Argo CD Vault Plugin**: Inlines secret references in manifests; plugin resolves them at sync time.
4. **SOPS + helm-secrets**: Encrypts values files; decrypted during template rendering.

The recommended approach for production is ESO + a secrets manager (Vault, AWS Secrets Manager).

---

## Argo CD — Advanced

### Q26: How does Argo CD detect and handle drift?

**Answer:**
Argo CD continuously compares **desired state** (Git) with **live state** (cluster):

1. Every 3 minutes (configurable), the controller re-renders manifests from Git.
2. It performs a structured diff against the live resources.
3. If differences are found, the Application status changes to `OutOfSync`.
4. With `selfHeal: true`, Argo CD automatically re-applies the desired state.
5. With manual sync, it reports the drift and waits for human approval.

You can also configure `ignoreDifferences` for fields managed by controllers (e.g., HPA managing `replicas`).

---

### Q27: What does `ignoreDifferences` do and when would you use it?

**Answer:**
```yaml
ignoreDifferences:
  - group: apps
    kind: Deployment
    jsonPointers:
      - /spec/replicas
```

This tells Argo CD to ignore the `replicas` field when comparing desired vs. live state. Without this, a HPA scaling the Deployment to 5 replicas would cause Argo CD to detect drift (because Git says 3) and revert it.

Common use cases:
- HPA-managed `replicas`
- Mutating admission webhooks that inject sidecars
- Controller-managed annotations (like cert-manager)

---

### Q28: How would you implement a promotion pipeline across environments?

**Answer:**
A GitOps promotion pipeline:

```
dev → staging → prod
```

**Process:**
1. Developer merges code → CI builds image `v1.2.3` → pushes to registry.
2. CI updates `environments/dev/values.yaml` with `image.tag: v1.2.3`.
3. Argo CD auto-syncs to dev.
4. After testing passes in dev, a PR is created to update `environments/staging/values.yaml`.
5. PR is merged → Argo CD auto-syncs to staging.
6. After staging QA, a PR updates `environments/prod/values.yaml`.
7. PR is merged → DevOps manually syncs prod in Argo CD.

Each promotion is a Git commit, providing a full audit trail.

---

### Q29: What are Argo CD sync waves and how do they work?

**Answer:**
Sync waves control the order of resource creation:

```yaml
metadata:
  annotations:
    argocd.argoproj.io/sync-wave: "0"   # Applied first
---
metadata:
  annotations:
    argocd.argoproj.io/sync-wave: "1"   # Applied second
```

Use case: Create a ConfigMap (wave 0) before the Deployment (wave 1) that references it. Resources in the same wave are applied in parallel. Argo CD waits until all resources in a wave are healthy before proceeding to the next wave.

---

### Q30: How do you implement RBAC in Argo CD?

**Answer:**
Argo CD uses its own RBAC system defined in `argocd-rbac-cm` ConfigMap:

```csv
p, role:developer, applications, get, */*, allow
p, role:developer, applications, sync, */webapp-dev, allow
p, role:devops, applications, *, */*, allow
g, dev-team, role:developer
g, ops-team, role:devops
```

This integrates with SSO (OIDC, SAML, LDAP). Groups from your identity provider map to Argo CD roles. Developers can view all apps but only sync dev; DevOps can do everything.

---

## Scenario-Based Questions

### S1: Your production deployment is broken. Walk me through how you would rollback.

**Answer:**

**Immediate (within minutes):**
1. Run `argocd app history webapp-prod` to identify the last good sync.
2. If using Helm directly: `helm rollback webapp-prod -n webapp-prod`.
3. If using Argo CD: `argocd app rollback webapp-prod <good-revision-id>`.
4. Monitor: `kubectl rollout status deployment/webapp-prod -n webapp-prod`.

**Permanent (GitOps way):**
1. `git log --oneline` to find the bad commit.
2. `git revert <bad-commit>` to create a revert commit.
3. `git push` — Argo CD detects the change.
4. `argocd app sync webapp-prod` (manual sync since prod is manual).
5. Verify: `kubectl get pods -n webapp-prod`, check health endpoints.

The Argo CD rollback is temporary — the next sync will re-apply Git state. Always do a `git revert` for a permanent fix.

---

### S2: A developer accidentally ran `kubectl scale deployment webapp-prod --replicas=0`. What happens?

**Answer:**

**With selfHeal enabled:**
Argo CD detects the drift within ~3 minutes and reverts the replica count back to the Git-declared value (e.g., 3). The outage is self-correcting.

**Without selfHeal (prod setup in this lab):**
The Application status changes to `OutOfSync`. Argo CD reports the drift but takes no action. An operator must:
1. Notice the drift via the Argo CD UI or alerts.
2. Run `argocd app sync webapp-prod` to restore the desired state.

**Prevention:** Use Kubernetes RBAC to restrict `kubectl scale` access in production namespaces.

---

### S3: You need to deploy the same application to 15 different customer environments. How would you scale this?

**Answer:**

1. **ApplicationSet controller**: Generates Argo CD Applications from a template:
```yaml
apiVersion: argoproj.io/v1alpha1
kind: ApplicationSet
metadata:
  name: webapp-customers
spec:
  generators:
    - git:
        repoURL: https://github.com/org/repo.git
        directories:
          - path: environments/*
  template:
    metadata:
      name: 'webapp-{{path.basename}}'
    spec:
      source:
        repoURL: https://github.com/org/repo.git
        path: helm-charts/webapp
        helm:
          valueFiles:
            - '../../environments/{{path.basename}}/values.yaml'
      destination:
        server: https://kubernetes.default.svc
        namespace: 'webapp-{{path.basename}}'
```

2. Add a new customer by creating `environments/<customer>/values.yaml`.
3. The ApplicationSet automatically generates the Application — no manual YAML needed.

---

### S4: How would you implement canary deployments with Helm and Argo CD?

**Answer:**

**Option 1: Argo Rollouts**
Replace the Deployment with a Rollout resource:
```yaml
apiVersion: argoproj.io/v1alpha1
kind: Rollout
spec:
  strategy:
    canary:
      steps:
        - setWeight: 20
        - pause: {duration: 5m}
        - setWeight: 50
        - pause: {duration: 5m}
        - setWeight: 100
```
Argo CD + Argo Rollouts work together: Argo CD syncs the Rollout, and Argo Rollouts manages the gradual traffic shift.

**Option 2: Istio / Service Mesh**
Use VirtualService + DestinationRule to split traffic between stable and canary versions.

**Option 3: Ingress-based**
Deploy a canary Deployment with a separate Ingress using weight annotations (supported by NGINX Ingress).

---

### S5: Your CI pipeline just built image `v2.0.0`. Describe the complete GitOps workflow from image build to production.

**Answer:**

```
1. CI pipeline:
   - Builds and tests the application
   - Creates Docker image v2.0.0
   - Pushes to container registry
   - Updates environments/dev/values.yaml: image.tag → "v2.0.0"
   - Commits and pushes to the repo

2. Dev deployment (automatic):
   - Argo CD detects the Git change
   - Renders Helm templates with dev values
   - Applies to the webapp-dev namespace
   - Rolling update replaces pods

3. Dev validation:
   - Automated smoke tests run against dev
   - Integration tests pass

4. Staging promotion (PR-based):
   - CI or a human creates a PR updating environments/staging/values.yaml
   - PR is reviewed and merged
   - Argo CD auto-syncs to staging

5. Staging validation:
   - QA tests, load tests, security scans

6. Production promotion (gated):
   - PR updates environments/prod/values.yaml: image.tag → "v2.0.0"
   - Requires approvals (2 reviewers)
   - PR is merged
   - Argo CD shows webapp-prod as OutOfSync
   - DevOps reviews the diff: argocd app diff webapp-prod
   - DevOps triggers sync: argocd app sync webapp-prod
   - Monitors rollout: kubectl rollout status deployment/webapp-prod

7. Post-deployment:
   - Monitoring dashboards confirm healthy metrics
   - If issues arise: git revert → push → manual sync
```

---

### S6: Your Helm upgrade failed midway. What happens to the Kubernetes resources?

**Answer:**

Helm uses a **three-way strategic merge**:

1. If `--atomic` flag is used: Helm automatically rolls back to the previous revision. All changes are undone.
2. If `--atomic` is NOT used: The release is marked as `FAILED`. Resources may be in a partially updated state (some pods on new version, some on old).
3. `--wait` flag ensures Helm waits for pods to become Ready. If they don't within `--timeout`, it's marked failed.

**Recovery:**
```bash
helm rollback webapp-dev -n webapp-dev    # Restore the last good state
helm history webapp-dev -n webapp-dev     # View what happened
```

**Best practice:** Always use `--wait --timeout 5m` and consider `--atomic` for critical environments.

---

### S7: How would you handle database schema migrations in a Helm + Argo CD workflow?

**Answer:**

Use **Helm hooks** with **Argo CD sync waves**:

```yaml
apiVersion: batch/v1
kind: Job
metadata:
  name: {{ include "webapp.fullname" . }}-migrate
  annotations:
    "helm.sh/hook": pre-upgrade
    "helm.sh/hook-delete-policy": before-hook-creation
    argocd.argoproj.io/sync-wave: "-1"   # Before the main app
spec:
  template:
    spec:
      containers:
        - name: migrate
          image: {{ include "webapp.image" . }}
          command: ["python", "manage.py", "migrate"]
      restartPolicy: Never
  backoffLimit: 3
```

Argo CD respects both Helm hooks and sync waves. The migration Job runs first (wave -1), and only after it succeeds does the Deployment update (wave 0).

---

## Architecture & Design Questions

### A1: Design a multi-cluster GitOps architecture for a company with 3 regions.

**Answer:**

```
                    ┌───────────────┐
                    │   Git Repo    │
                    │  (single      │
                    │   source of   │
                    │   truth)      │
                    └───────┬───────┘
                            │
              ┌─────────────┼──────────────┐
              ▼             ▼              ▼
      ┌──────────┐  ┌──────────┐  ┌──────────┐
      │ Argo CD  │  │ Argo CD  │  │ Argo CD  │
      │ (US-East)│  │ (EU-West)│  │ (AP-SE)  │
      └──────────┘  └──────────┘  └──────────┘
```

**Approach:** Hub-spoke model with Argo CD in each cluster:
- Central Git repo with per-region values files.
- Each cluster has its own Argo CD instance.
- ApplicationSets generate region-specific Applications.
- Secrets managed via External Secrets Operator + regional Vault clusters.

---

### A2: How would you structure a Helm chart for a microservices platform with 20+ services?

**Answer:**

**Option 1: Library chart**
- Create a `base-service` library chart with common templates.
- Each microservice has a thin chart that depends on `base-service` and only provides values.

**Option 2: Shared chart with per-service values**
- Single generic chart (like the `webapp` chart in this lab).
- Each microservice has its own values file.
- Use ApplicationSets to generate Applications from a directory of values files.

**Option 3: Umbrella chart**
- A parent chart that includes all microservices as sub-charts.
- Good for tightly coupled services deployed together.
- Bad for independent release cycles.

Recommendation: Option 2 for most teams; Option 1 for large organizations with strict standards.

---

### A3: Compare Argo CD vs. Flux CD.

**Answer:**

| Feature | Argo CD | Flux CD |
|---|---|---|
| UI | Rich web UI | No built-in UI (use Weave GitOps) |
| CRD model | Application, AppProject | GitRepository, Kustomization, HelmRelease |
| Multi-tenancy | AppProjects with RBAC | Namespaced resources with RBAC |
| Helm support | `helm template` (no release tracking) | Native `helm install/upgrade` |
| SSO | Built-in (OIDC, SAML, LDAP) | Depends on UI |
| Notifications | Built-in notifications controller | Separate notification controller |
| Sync waves | Yes | Depends on Kustomize ordering |
| App-of-Apps | Native pattern | Use Flux Kustomization nesting |

Both are CNCF projects. Argo CD is preferred when a UI and centralized management are important. Flux is preferred for lightweight, controller-based approaches.

---

## Troubleshooting Scenarios

### T1: Argo CD shows an Application as "OutOfSync" even though you haven't made any changes. Why?

**Answer:**
Common causes:
1. **Mutating admission webhooks**: A webhook (e.g., Istio sidecar injector) modifies resources after creation, causing drift. Fix: add `ignoreDifferences` for the injected fields.
2. **Default values applied by the API server**: Kubernetes API sets defaults (e.g., `imagePullPolicy: Always` for `:latest` tags). Fix: explicitly set the field in your chart.
3. **HPA changing replicas**: The HPA scales the Deployment, but Git declares a different replica count. Fix: use `ignoreDifferences` for `/spec/replicas`.
4. **Timestamp annotations**: Some controllers add timestamps that constantly change.

Debug: `argocd app diff webapp-dev` shows exactly what's different.

---

### T2: `helm upgrade` is stuck in "pending-upgrade" state.

**Answer:**

```bash
# Check the status
helm list -n <namespace> -a

# The release is stuck because a previous upgrade never completed.
# Option 1: Force rollback
helm rollback <release> <last-good-revision> -n <namespace>

# Option 2: If rollback fails, delete the pending release secret
kubectl get secrets -n <namespace> -l owner=helm
# Delete the secret for the pending revision
kubectl delete secret sh.helm.release.v1.<release>.v<revision> -n <namespace>

# Then retry the upgrade
helm upgrade --install <release> <chart> -f <values>
```

---

### T3: Pods are in `ImagePullBackOff`. How do you debug this?

**Answer:**

```bash
# 1. Check the pod events
kubectl describe pod <pod-name> -n <namespace>
# Look for: "Failed to pull image" messages

# 2. Common causes:
# a) Wrong image tag → check values.yaml image.tag
# b) Private registry without imagePullSecrets → add imagePullSecrets in values
# c) Registry rate limit (Docker Hub) → use authenticated pulls
# d) Image doesn't exist → verify in the registry

# 3. Test the image manually
docker pull <image>:<tag>

# 4. Check imagePullSecrets
kubectl get secret <secret-name> -n <namespace> -o jsonpath='{.data.\.dockerconfigjson}' | base64 -d
```

---

## Rapid-Fire / One-Liner Answers

| # | Question | Answer |
|---|---|---|
| 1 | Difference between `helm install` and `helm upgrade`? | `install` creates; `upgrade` updates an existing release. |
| 2 | What does `helm lint` do? | Validates chart structure and templates for errors. |
| 3 | What is a Helm repository? | A server hosting `index.yaml` + packaged `.tgz` charts. |
| 4 | What does `--atomic` do? | Auto-rollbacks on failure during install/upgrade. |
| 5 | What is a Helm plugin? | An extension that adds CLI commands (e.g., `helm diff`, `helm secrets`). |
| 6 | How often does Argo CD poll Git? | Every 3 minutes by default (configurable). |
| 7 | Can Argo CD use webhooks? | Yes, GitHub/GitLab/Bitbucket webhooks for instant detection. |
| 8 | What is `selfHeal` in Argo CD? | Reverts manual cluster changes back to the Git-declared state. |
| 9 | What is `prune` in Argo CD? | Deletes cluster resources that no longer exist in Git. |
| 10 | Can you use Kustomize with Argo CD? | Yes, Argo CD supports Helm, Kustomize, Jsonnet, and plain YAML. |
| 11 | What is the Argo CD Application health model? | Healthy, Progressing, Degraded, Suspended, Missing, Unknown. |
| 12 | What is `targetRevision` in an Application? | The Git branch, tag, or commit SHA to track. |
| 13 | What is `helm diff`? | A plugin that shows what would change on the next upgrade. |
| 14 | How do you pass multiple values files? | `helm upgrade -f base.yaml -f override.yaml` (last file wins). |
| 15 | What is `Release.Revision` in Helm templates? | The revision number of the current install/upgrade. |
| 16 | Can Argo CD deploy to multiple clusters? | Yes, register clusters with `argocd cluster add`. |
| 17 | What happens if you delete an Argo CD Application? | Resources are deleted if the `resources-finalizer` is present. |
| 18 | What is a sync wave? | Controls the order of resource creation during sync. |
| 19 | How do you skip Argo CD sync for a resource? | Annotate with `argocd.argoproj.io/sync-options: SkipDryRun=true`. |
| 20 | What is `helm get values`? | Shows the values used for the current release. |

---

## Tips for the Interview

1. **Always start with the "why"** before diving into the "how." Explain the problem before the solution.
2. **Draw diagrams** (even on a whiteboard) when explaining GitOps workflows.
3. **Reference real scenarios** from this lab to demonstrate hands-on experience.
4. **Know the trade-offs** — e.g., auto-sync vs. manual sync, Argo CD vs. Flux, Helm vs. Kustomize.
5. **Security matters** — always mention secrets management, RBAC, and least privilege.
6. **Mention observability** — how you monitor deployments (Prometheus, Grafana, Argo CD notifications).
7. **Practice the commands** — interviewers often ask you to write Helm/kubectl commands live.

---

## Further Reading

- [Helm Documentation](https://helm.sh/docs/)
- [Argo CD Documentation](https://argo-cd.readthedocs.io/)
- [GitOps Principles (OpenGitOps)](https://opengitops.dev/)
- [Argo CD Best Practices](https://argo-cd.readthedocs.io/en/stable/user-guide/best_practices/)
- [Helm Chart Best Practices](https://helm.sh/docs/chart_best_practices/)
