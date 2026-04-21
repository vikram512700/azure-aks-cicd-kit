# Azure AKS CI/CD Kit

> **⚠️ This kit is built for KodeKloud's Azure Playground.** You do **NOT** have permission to create users, service principals, or subscription-scope role assignments. Everything is scoped to the single pre-existing resource group that regenerates every 3 hours.

Auto-deploy containerized **Python Flask** + **Node.js Express** apps to **AKS** using **Terraform**, **Git**, and **Azure Pipelines**.

---

## Architecture

```
┌─────────────────────────────────────────────────────────────────────┐
│                    KodeKloud Playground RG                         │
│                                                                     │
│  ┌──────────┐   ┌───────────┐   ┌──────────────┐   ┌───────────┐  │
│  │ Storage  │   │    ACR    │   │     AKS      │   │ Key Vault │  │
│  │ Account  │   │  (Basic)  │   │ 2x D2s_v3   │   │ (Standard)│  │
│  │ (tfstate)│   │           │   │              │   │           │  │
│  └──────────┘   └─────┬─────┘   │ ┌──────────┐│   └─────┬─────┘  │
│                       │         │ │  NGINX   ││         │        │
│                       │ AcrPull │ │  Ingress ││  KV CSI │        │
│                       │ (kubelet│ │    LB    ││  Secrets│        │
│                       │  MI)    │ ├──────────┤│  User   │        │
│                       └─────────┤ │python-app││─────────┘        │
│                                 │ │nodejs-app││                  │
│                                 │ └──────────┘│                  │
│                                 └──────────────┘                  │
│                                                                     │
│  ┌──────────────────┐   ┌─────────────────────────────┐            │
│  │ Log Analytics    │   │ VNet 10.0.0.0/16            │            │
│  │ (PerGB2018)      │   │   └─ AKS Subnet 10.0.1.0/24│            │
│  └──────────────────┘   └─────────────────────────────┘            │
└─────────────────────────────────────────────────────────────────────┘
```

## CI/CD Flow

```
git push main → Azure Pipelines triggers
  ├─ Stage 1: Validate (YAML lint, Dockerfile check)
  ├─ Stage 2: Build & Push (Docker → ACR, tags: BuildId + latest)
  └─ Stage 3: Deploy (kubectl set image → rolling update → zero downtime)
       └─ App live via ingress in 2–3 minutes
```

---

## 🚀 Setup — 6 Steps

### Prerequisites

- KodeKloud Azure Playground lab **active** (3-hour window)
- `az login` completed (use the playground credentials)
- Tools installed: `terraform`, `kubectl`, `kubelogin`, `az` CLI

---

### Step 1: Copy the Playground Resource Group Name

Open the KodeKloud Playground UI → copy the **Resource Group** name (it changes every session).

### Step 2: Create `terraform.tfvars`

```bash
cd terraform/
cp terraform.tfvars.example terraform.tfvars
```

Edit `terraform.tfvars` and paste your RG name:

```hcl
resource_group_name = "1-a1b2c3d4-playground-sandbox"  # ← paste yours
```

### Step 3: Bootstrap Terraform State (once per session)

```bash
cd bootstrap/
chmod +x bootstrap-backend.sh
./bootstrap-backend.sh "<YOUR_RG_NAME>"
```

This creates a Storage Account for Terraform state and prints the `terraform init` flags.

### Step 4: Deploy Infrastructure

```bash
cd terraform/

# Option A: Use the printed flags
terraform init -reconfigure \
  -backend-config="resource_group_name=<RG_NAME>" \
  -backend-config="storage_account_name=<SA_NAME>" \
  -backend-config="container_name=tfstate" \
  -backend-config="key=aks-cicd-kit.tfstate"

# Option B: Use the generated backend.hcl
terraform init -reconfigure -backend-config=backend.hcl

# Review and apply
terraform plan
terraform apply
```

After `terraform apply`, note these outputs:
- `acr_login_server` — for Docker push
- `keyvault_name` — for SecretProviderClass
- `kv_csi_identity_client_id` — for SecretProviderClass
- `tenant_id` — for SecretProviderClass
- `aks_get_credentials_command` — run this next

### Step 5: Configure AKS & Deploy K8s Manifests

```bash
# Get AKS credentials
az aks get-credentials \
  --resource-group <RG_NAME> \
  --name aks-cicd-cluster \
  --overwrite-existing

# Install NGINX ingress controller
kubectl apply -f https://raw.githubusercontent.com/kubernetes/ingress-nginx/controller-v1.10.0/deploy/static/provider/cloud/deploy.yaml

# Update k8s/secretproviderclass.yaml with Terraform outputs:
#   userAssignedIdentityID: <kv_csi_identity_client_id>
#   keyvaultName:           <keyvault_name>
#   tenantId:               <tenant_id>

# Apply all K8s manifests
kubectl apply -f k8s/

# Build and push initial images manually (first time only)
az acr login --name <ACR_NAME>
docker build -t <ACR_LOGIN_SERVER>/python-app:latest ./app-python
docker push <ACR_LOGIN_SERVER>/python-app:latest
docker build -t <ACR_LOGIN_SERVER>/nodejs-app:latest ./app-nodejs
docker push <ACR_LOGIN_SERVER>/nodejs-app:latest

# Restart deployments to pick up images
kubectl rollout restart deployment/python-app -n apps
kubectl rollout restart deployment/nodejs-app -n apps
```

### Step 6: Set Up Azure DevOps Pipeline

1. Push this repo to Azure DevOps (or GitHub connected to Azure DevOps)
2. Create **Service Connections** (Project Settings → Service connections):
   - `acr-service-connection` — Azure RM, scoped to your current RG
   - `aks-service-connection` — Azure RM, scoped to your current RG
3. Create **Pipeline Variables** (or a Variable Group):
   - `ACR_NAME` — from `terraform output acr_name`
   - `ACR_LOGIN_SERVER` — from `terraform output acr_login_server`
   - `AKS_RESOURCE_GROUP` — your playground RG name
   - `AKS_CLUSTER_NAME` — from `terraform output aks_cluster_name`
4. Create a new pipeline pointing to `.azure-pipelines/azure-pipelines.yml`
5. Push to `main` → pipeline triggers automatically

### Verify

```bash
kubectl get pods -n apps          # Should show 2/2 Running for each app
kubectl get ingress -n apps       # Note the EXTERNAL-IP
curl http://<EXTERNAL-IP>/python  # Python app response
curl http://<EXTERNAL-IP>/nodejs  # Node.js app response
```

---

## 📁 Project Structure

```
azure-aks-cicd-kit/
├── terraform/
│   ├── backend.tf                    # Remote state config (partial)
│   ├── providers.tf                  # azurerm ~> 4.0
│   ├── main.tf                       # AKS, ACR, Key Vault, Log Analytics
│   ├── network.tf                    # VNet + Subnet + NSG
│   ├── rbac.tf                       # Role assignments (RG/resource-scoped)
│   ├── variables.tf                  # All variables with validation
│   ├── outputs.tf                    # Key outputs + next-steps banner
│   └── terraform.tfvars.example      # Template — paste RG name here
├── bootstrap/
│   └── bootstrap-backend.sh          # Creates state Storage Account
├── k8s/
│   ├── namespace.yaml                # Namespace: apps
│   ├── secretproviderclass.yaml      # KV CSI → K8s Secret sync
│   ├── python-deployment.yaml        # Flask app (2 replicas, CSI vol)
│   ├── python-service.yaml           # ClusterIP → port 5000
│   ├── nodejs-deployment.yaml        # Express app (2 replicas, CSI vol)
│   ├── nodejs-service.yaml           # ClusterIP → port 3000
│   └── ingress.yaml                  # NGINX: /python, /nodejs
├── .azure-pipelines/
│   ├── azure-pipelines.yml           # Main pipeline (3 stages)
│   └── templates/
│       ├── build-push.yml            # Reusable: Docker build + ACR push
│       └── deploy-aks.yml            # Reusable: AKS deploy + rollout
├── app-python/
│   ├── app.py                        # Flask app
│   ├── requirements.txt              # Python deps
│   └── Dockerfile                    # Multi-stage, non-root
├── app-nodejs/
│   ├── index.js                      # Express app
│   ├── package.json                  # Node deps
│   └── Dockerfile                    # Multi-stage, non-root
└── README.md                         # This file
```

---

## 🔐 Security Design

| Concern | Approach |
|---|---|
| **ACR image pull** | AKS kubelet managed identity + `AcrPull` role (scoped to ACR) |
| **Key Vault secrets** | CSI addon identity + `Key Vault Secrets User` role (scoped to KV) |
| **Network** | Kubenet, NSG allows only HTTP/HTTPS inbound |
| **Container security** | `runAsNonRoot`, `readOnlyRootFilesystem`, drop all capabilities |
| **No subscription perms** | All role assignments scoped to RG or resource ID |
| **No service principals** | System-assigned managed identities only |

---

## 🔧 Troubleshooting

### 1. ACR ImagePullBackOff

```bash
# Check if AcrPull role is assigned
az role assignment list --scope $(az acr show --name <ACR_NAME> --query id -o tsv) -o table

# Verify kubelet identity
kubectl describe pod <pod-name> -n apps | grep -A5 "Events"

# Fix: ensure terraform applied rbac.tf successfully
terraform apply -target=azurerm_role_assignment.acr_pull
```

### 2. Key Vault CSI Secret Not Mounting

```bash
# Check SecretProviderClass
kubectl describe secretproviderclass azure-kv-secrets -n apps

# Check CSI driver pods
kubectl get pods -n kube-system | grep secrets-store

# Verify role assignment
az role assignment list --scope $(az keyvault show --name <KV_NAME> --query id -o tsv) -o table

# Common fix: userAssignedIdentityID in secretproviderclass.yaml doesn't match
# terraform output kv_csi_identity_client_id
```

### 3. Ingress IP Stuck Pending

```bash
# Check ingress controller is running
kubectl get pods -n ingress-nginx

# If not installed:
kubectl apply -f https://raw.githubusercontent.com/kubernetes/ingress-nginx/controller-v1.10.0/deploy/static/provider/cloud/deploy.yaml

# Wait for LB IP (takes 1-3 minutes)
kubectl get svc -n ingress-nginx --watch
```

### 4. Terraform State Lock After Lab Reset

The lab reset deleted your Storage Account but Terraform thinks the lock still exists.

```bash
# Option A: Re-run bootstrap (creates fresh SA)
./bootstrap/bootstrap-backend.sh <NEW_RG_NAME>
terraform init -reconfigure -backend-config=backend.hcl

# Option B: If SA still exists, delete the lock blob
az storage blob delete \
  --account-name <SA_NAME> \
  --container-name tfstate \
  --name aks-cicd-kit.tfstate.lock
```

### 5. "AuthorizationFailed" on Role Assignment

This means you hit a **subscription-scope** operation. The playground doesn't allow this.

```bash
# Check the error — if scope starts with /subscriptions/... that's the problem
# All scopes must be /subscriptions/.../resourceGroups/<RG>/...

# Fix: ensure rbac.tf uses resource-level scopes, not subscription
# ✅ scope = azurerm_container_registry.acr.id
# ❌ scope = "/subscriptions/${data.azurerm_client_config.current.subscription_id}"
```

---

## ⏱️ Session Lifecycle

| Event | Action |
|---|---|
| **New 3-hour session** | Copy RG name → update `terraform.tfvars` → re-run bootstrap + `terraform apply` |
| **Session expires** | Everything is destroyed. State, cluster, images — all gone. That's expected. |
| **Same session, code change** | `git push main` → pipeline auto-deploys (if Azure DevOps is set up) |
| **Same session, manual deploy** | `docker build` → `docker push` → `kubectl set image` |
