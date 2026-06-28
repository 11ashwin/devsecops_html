# DevSecOps Kubernetes Pipeline

An end-to-end secure CI/CD pipeline that integrates vulnerability scanning, GitOps deployment, and runtime threat detection — security built into every stage, not bolted on at the end.

---

## Overview

This project deploys a containerised web application to a local Kubernetes cluster using a fully automated pipeline. Every `git push` triggers a chain that builds, scans, publishes, and deploys — with Falco watching every container action at runtime and Grafana surfacing the results.

```
Developer (git push)
    │
    ▼
GitHub Repository          source code + Kubernetes manifests
    │
    ▼
GitHub Actions CI/CD
    ├── Docker build        ARM64 + AMD64 multi-arch
    ├── Trivy scan          block on HIGH / CRITICAL CVEs
    ├── Push to Docker Hub  versioned image tag
    └── Update manifest     deployment.yaml image tag
                │
                ▼
           Argo CD           watches Git → syncs cluster automatically
                │
                ▼
    Kubernetes (Minikube)
                │
    ┌───────────┼──────────────┐
    │           │              │
    ▼           ▼              ▼
Resume app   Falco         Prometheus
               │                │
               ▼                ▼
         Falcosidekick       Grafana
```

---

## Stack

| Layer | Tool | Purpose |
|---|---|---|
| Source control | GitHub | Code + manifest repository |
| CI/CD | GitHub Actions | Build, scan, push, deploy automation |
| Container build | Docker | Multi-arch image (ARM64/AMD64) |
| Vulnerability scan | Trivy | Block HIGH/CRITICAL CVEs before push |
| Image registry | Docker Hub | Versioned image storage |
| GitOps | Argo CD | Declarative cluster sync from Git |
| Orchestration | Kubernetes (Minikube) | Local cluster with NGINX Ingress |
| Runtime security | Falco + Falcosidekick | Kernel-level container threat detection |
| Metrics | Prometheus | Falco alert scraping and storage |
| Visualisation | Grafana | Alert dashboards by severity, rule, pod |

---

## Security Design

### Shift left — scan before it ships
Trivy runs against the Docker image inside GitHub Actions. Any HIGH or CRITICAL CVE fails the pipeline. Nothing reaches Docker Hub unless it's clean.

### Least privilege containers
All containers run as non-root with default Linux capabilities dropped via Pod Security Contexts. If a container is compromised, the attacker's reach within the host is minimal.

### Immutable infrastructure via GitOps
No one SSHes into a server to make changes. Every deployment is a Git commit. Argo CD reconciles the cluster against the repository continuously — no configuration drift, no snowflakes.

### Runtime visibility with Falco
Falco runs as a DaemonSet and watches container behaviour at the kernel syscall level. It fires structured alerts when rules match — unexpected shell spawns, API server contact, anomalous file writes. Falcosidekick routes those alerts to Prometheus; Grafana makes them visible.

---

## Falco Rules Tested

| Rule | Trigger | Severity |
|---|---|---|
| Terminal shell in container | `kubectl exec` into a running pod | Notice |
| Run shell untrusted | Process spawned a shell outside expected startup paths | Notice |
| Contact K8s API server | Pod attempted to reach the cluster control plane | Notice |

---

## Project Status

| Component | Status |
|---|---|
| Resume website — static HTML/CSS via NGINX | ✅ Complete |
| Docker — multi-arch, non-root, Docker Hub push | ✅ Complete |
| GitHub Actions CI — build, scan, push, tag | ✅ Complete |
| Trivy — image and IaC vulnerability scanning | ✅ Complete |
| Kubernetes — Minikube cluster, NGINX Ingress | ✅ Complete |
| Argo CD / GitOps — synced, auto-deploy on push | ✅ Complete |
| Falco — runtime container threat detection | ✅ Complete |
| Prometheus — metrics scraping, ServiceMonitor | ✅ Complete |
| Grafana — severity, rules, namespace, pod panels | ✅ Complete |
| Manifest auto-update — Actions commits new image tag | 🔄 In progress |
| GitHub Pages — public portfolio hosting | 📋 Planned |
| Automation scripts — install.sh, start.sh, port-forward.sh | 📋 Planned |

---

## Local Setup

> Prerequisites: Docker, Minikube, kubectl, Helm, Argo CD CLI

**1. Start the cluster**
```bash
minikube start --driver=docker
minikube addons enable ingress
```

**2. Install Argo CD**
```bash
kubectl create namespace argocd
kubectl apply -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml
```

**3. Deploy the application via Argo CD**
```bash
argocd app create resume \
  --repo https://github.com/<your-repo> \
  --path k8s \
  --dest-server https://kubernetes.default.svc \
  --dest-namespace default \
  --sync-policy automated
```

**4. Install Falco**
```bash
helm repo add falcosecurity https://falcosecurity.github.io/charts
helm install falco falcosecurity/falco \
  --set falcosidekick.enabled=true \
  --set falcosidekick.config.prometheusexporter.enabled=true
```

**5. Install Prometheus + Grafana**
```bash
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
helm install kube-prometheus prometheus-community/kube-prometheus-stack
```

**6. Access the app**
```bash
minikube tunnel
# then visit http://resume.local (add to /etc/hosts if needed)
```

---

## CI/CD Pipeline (GitHub Actions)

On every push to `main`:

1. **Build** — multi-arch Docker image for `linux/amd64` and `linux/arm64`
2. **Scan** — Trivy scans the image; pipeline fails on HIGH or CRITICAL findings
3. **Push** — tagged image pushed to Docker Hub using repository secrets
4. **Deploy** — Argo CD detects the new manifest tag and syncs the cluster automatically

Secrets required in GitHub repository settings:

| Secret | Value |
|---|---|
| `DOCKER_USERNAME` | Docker Hub username |
| `DOCKER_PASSWORD` | Docker Hub access token |

---

## Author

**Ashwin Yadav** — Senior Cybersecurity Engineer  
[linkedin.com/in/ashwinyadav11](https://linkedin.com/in/ashwinyadav11) · ashwin09yadav@gmail.com