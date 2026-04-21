# Azure AKS CI/CD Kit

> **⚠️ This kit is built for KodeKloud's Azure Playground.** You do **NOT** have permission to create users, service principals, role assignments, or subscription-scope operations. Everything is scoped to the single pre-existing resource group that regenerates every 3 hours.

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
│  │ (tfstate)│   │ admin=on  │   │              │   │ access    │  │
│  └──────────┘   └─────┬─────┘   │ ┌──────────┐│   │ policy    │  │
│                       │         │ │  NGINX   ││   └─────┬─────┘  │
│                       │ pull    │ │  Ingress ││  CSI    │        │
│                       │ secret  │ │    LB    ││  addon  │        │
│                       │         │ ├──────────┤│         │        │
│                       └─────────┤ │python-app││─────────┘        │
│                                 │ │nodejs-app││                  │
│                                 │ └──────────┘│                  │
│                                 └──────────────┘                  │
│                                                                     │
│  ┌─────────────────────────────┐                                   │
│  │ VNet 10.0.0.0/16           │                                   │
│  │   └─ AKS Subnet 10.0.1.0/24│                                  │
│  └─────────────────────────────┘                                   │
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

## Sandbox Constraints (Learned the Hard Way)

| What's Blocked | Workaround Used |
|---|---|
| **Role assignments** (even at resource scope) | ACR: `admin_enabled = true` + `imagePullSecret`. KV: access policies (not RBAC) |
| **Log Analytics / ContainerInsights** | Removed `oms_agent` block from AKS entirely |
| **Changing KV permission model** | Must create KV with `rbac_authorization_enabled = false` from the start |
| **Purging deleted Key Vaults** | Use a new KV name if old one is stuck in soft-delete |
| **`az aks update --attach-acr`** | Fails (needs role assignment). Use `imagePullSecret` instead |
| **Provider registration** | Set `resource_provider_registrations = "none"` in provider block |

---

## 🚀 Setup — 6 Steps

### Prerequisites

- **Ubuntu VM** with tools installed (run `install-deps.sh`):
  - `git`, `az` CLI, `terraform`, `kubectl`, `kubelogin`, `docker`, `helm`
- KodeKloud Azure Playground lab **active** (3-hour window)
- `az login --use-device-code` completed

---

### Step 1: Copy the Playground Resource Group Name

Open the KodeKloud Playground UI → copy the **Resource Group** name (it changes every session).

### Step 2: Create Terraform State Storage (once per session)

```bash
# Replace with YOUR RG name
RG_NAME="paste-your-rg-name-here"

az storage account create \
  --name tfstatevikram2025 \
  --resource-group "$RG_NAME" \
  --location centralus \
  --sku Standard_LRS

az storage container create \
  --name tfstate \
  --account-name tfstatevikram2025 \
  --auth-mode login
```

### Step 3: Clone & Configure

```bash
git clone https://github.com/vikram512700/azure-aks-cicd-kit.git
cd azure-aks-cicd-kit/terraform

# Create terraform.tfvars
cat > terraform.tfvars << EOF
resource_group_name = "$RG_NAME"
keyvault_name       = "akscicdkv2"
EOF
```

### Step 4: Deploy Infrastructure

```bash
terraform init -reconfigure \
  -backend-config="resource_group_name=$RG_NAME" \
  -backend-config="storage_account_name=tfstatevikram2025" \
  -backend-config="container_name=tfstate" \
  -backend-config="key=aks-cicd-kit.tfstate" \
  -backend-config="use_azuread_auth=true"

terraform plan
terraform apply -auto-approve
```

After apply, note these outputs:
- `acr_login_server`, `acr_name`
- `keyvault_name`, `kv_csi_identity_client_id`, `tenant_id`

### Step 5: Post-Terraform Setup

```bash
# Save outputs to variables
ACR_NAME=$(terraform output -raw acr_name)
ACR_SERVER=$(terraform output -raw acr_login_server)
ACR_USER=$(terraform output -raw acr_admin_username)
ACR_PASS=$(terraform output -raw acr_admin_password)
KV_NAME=$(terraform output -raw keyvault_name)
KV_CSI_ID=$(terraform output -raw kv_csi_identity_client_id)
TENANT_ID=$(terraform output -raw tenant_id)

# Get AKS credentials
az aks get-credentials --resource-group $RG_NAME --name aks-cicd-cluster --overwrite-existing

# Add KV access policy for CSI addon
az keyvault set-policy --name $KV_NAME \
  --object-id $(az aks show -g $RG_NAME -n aks-cicd-cluster --query "addonProfiles.azureKeyvaultSecretsProvider.identity.objectId" -o tsv) \
  --secret-permissions get list

# Update K8s manifests with real values
cd ..
sed -i "s/<REPLACE_WITH_kv_csi_identity_client_id>/$KV_CSI_ID/g" k8s/secretproviderclass.yaml
sed -i "s/<REPLACE_WITH_keyvault_name>/$KV_NAME/g" k8s/secretproviderclass.yaml
sed -i "s/<REPLACE_WITH_tenant_id>/$TENANT_ID/g" k8s/secretproviderclass.yaml
sed -i "s/<ACR_LOGIN_SERVER>/$ACR_SERVER/g" k8s/python-deployment.yaml
sed -i "s/<ACR_LOGIN_SERVER>/$ACR_SERVER/g" k8s/nodejs-deployment.yaml

# Install NGINX ingress controller
kubectl apply -f https://raw.githubusercontent.com/kubernetes/ingress-nginx/controller-v1.10.0/deploy/static/provider/cloud/deploy.yaml

# Create namespace + ACR pull secret
kubectl apply -f k8s/namespace.yaml
kubectl create secret docker-registry acr-pull-secret \
  --namespace apps \
  --docker-server=$ACR_SERVER \
  --docker-username=$ACR_USER \
  --docker-password=$ACR_PASS
```

### Step 6: Build, Push & Deploy

```bash
# Build and push Docker images
docker login $ACR_SERVER -u $ACR_USER -p $ACR_PASS
docker build -t $ACR_SERVER/python-app:latest ./app-python
docker push $ACR_SERVER/python-app:latest
docker build -t $ACR_SERVER/nodejs-app:latest ./app-nodejs
docker push $ACR_SERVER/nodejs-app:latest

# Apply all K8s manifests
kubectl apply -f k8s/

# Verify
kubectl get pods -n apps
kubectl get ingress -n apps

# Get the external IP
INGRESS_IP=$(kubectl get svc -n ingress-nginx ingress-nginx-controller -o jsonpath='{.status.loadBalancer.ingress[0].ip}')
echo "App URLs:"
echo "  Python: http://$INGRESS_IP/python"
echo "  Node:   http://$INGRESS_IP/nodejs"

# Test
curl http://$INGRESS_IP/python
curl http://$INGRESS_IP/nodejs
```

---

## 📁 Project Structure

```
azure-aks-cicd-kit/
├── terraform/
│   ├── backend.tf                    # Remote state (use_azuread_auth)
│   ├── providers.tf                  # azurerm ~> 4.0, skip provider registration
│   ├── main.tf                       # AKS, ACR (admin), KV (access policies)
│   ├── network.tf                    # VNet + Subnet + NSG
│   ├── rbac.tf                       # DISABLED — sandbox blocks role assignments
│   ├── variables.tf                  # All variables with validation
│   ├── outputs.tf                    # Key outputs + post-apply commands
│   └── terraform.tfvars.example      # Template — paste RG name here
├── bootstrap/
│   └── bootstrap-backend.sh          # Creates state Storage Account
├── k8s/
│   ├── namespace.yaml                # Namespace: apps
│   ├── secretproviderclass.yaml      # KV CSI → K8s Secret sync
│   ├── python-deployment.yaml        # Flask (2 replicas, imagePullSecret, CSI)
│   ├── python-service.yaml           # ClusterIP → port 5000
│   ├── nodejs-deployment.yaml        # Express (2 replicas, imagePullSecret, CSI)
│   ├── nodejs-service.yaml           # ClusterIP → port 3000
│   └── ingress.yaml                  # NGINX: /python, /nodejs
├── .azure-pipelines/
│   ├── azure-pipelines.yml           # Main pipeline (3 stages)
│   └── templates/
│       ├── build-push.yml            # Reusable: Docker build + ACR push
│       └── deploy-aks.yml            # Reusable: AKS deploy + rollout
├── app-python/
│   ├── app.py                        # Flask app (/health, /)
│   ├── requirements.txt              # Flask + Gunicorn
│   └── Dockerfile                    # Multi-stage, non-root
├── app-nodejs/
│   ├── index.js                      # Express app (/health, /)
│   ├── package.json                  # Express
│   └── Dockerfile                    # Multi-stage, non-root
├── install-deps.sh                   # Install all tools on Ubuntu VM
└── README.md                         # This file
```

---

## 🔐 Security Design (Sandbox-Compatible)

| Concern | Approach |
|---|---|
| **ACR image pull** | `admin_enabled = true` + `imagePullSecret` in deployments |
| **Key Vault secrets** | Access policies (not RBAC) + CSI addon identity |
| **Network** | Kubenet, NSG allows only HTTP/HTTPS inbound |
| **Container security** | `runAsNonRoot`, `readOnlyRootFilesystem`, drop all capabilities |
| **No subscription perms** | No role assignments — all workarounds are resource-level |

---

## 🔧 Troubleshooting

### 1. ACR ImagePullBackOff

```bash
# Check if imagePullSecret exists
kubectl get secret acr-pull-secret -n apps

# If missing, recreate it:
ACR_USER=$(terraform -chdir=terraform output -raw acr_admin_username)
ACR_PASS=$(terraform -chdir=terraform output -raw acr_admin_password)
kubectl create secret docker-registry acr-pull-secret \
  --namespace apps \
  --docker-server=<ACR_LOGIN_SERVER> \
  --docker-username=$ACR_USER \
  --docker-password=$ACR_PASS
```

### 2. Key Vault CSI Secret Not Mounting

```bash
# Verify the access policy was added
az keyvault show --name <KV_NAME> --query "properties.accessPolicies"

# Check CSI driver pods
kubectl get pods -n kube-system | grep secrets-store

# Check SecretProviderClass values match terraform output
kubectl describe secretproviderclass azure-kv-secrets -n apps
```

### 3. Ingress IP Stuck Pending

```bash
# Check ingress controller pods
kubectl get pods -n ingress-nginx

# Wait for LoadBalancer IP (1-3 minutes)
kubectl get svc -n ingress-nginx --watch
```

### 4. Terraform State Lock After Lab Reset

```bash
# Lab reset deleted your SA — just re-bootstrap
az storage account create --name tfstatevikram2025 --resource-group <NEW_RG> --location centralus --sku Standard_LRS
az storage container create --name tfstate --account-name tfstatevikram2025 --auth-mode login
terraform init -reconfigure -backend-config="resource_group_name=<NEW_RG>" ...
```

### 5. Key Vault Name Conflict (Soft Delete)

```bash
# If old KV is stuck in soft-delete and can't be purged, use a new name:
# In terraform.tfvars:
keyvault_name = "akscicdkv3"
```

### 6. "AuthorizationFailed" on Any Operation

This means you hit a **subscription-scope** operation. The sandbox doesn't allow this.

```bash
# Common culprits:
# ❌ az aks update --attach-acr  (creates role assignment)
# ❌ azurerm_role_assignment     (any scope)
# ❌ az keyvault purge           (subscription-scope read)
# ❌ Changing KV from RBAC → access policy mode

# Fix: use the workarounds in this kit (admin creds, access policies, imagePullSecrets)
```

---

## ⏱️ Session Lifecycle

| Event | Action |
|---|---|
| **New 3-hour session** | Copy RG name → create state SA → update `terraform.tfvars` → `terraform apply` → post-setup |
| **Session expires** | Everything is destroyed. State, cluster, images — all gone. That's expected. |
| **Same session, code change** | `git push main` → pipeline auto-deploys (if Azure DevOps is set up) |
| **Same session, manual deploy** | `docker build` → `docker push` → `kubectl set image` |
