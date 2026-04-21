#!/usr/bin/env bash
# =============================================================================
# bootstrap-backend.sh — Create Terraform state Storage Account
# =============================================================================
# Usage:  ./bootstrap-backend.sh <RESOURCE_GROUP_NAME>
#
# Creates a Storage Account + blob container inside the existing playground RG
# for Terraform remote state. Idempotent — skips if the SA already exists.
#
# Run this ONCE at the start of each 3-hour KodeKloud lab session.
# =============================================================================

set -euo pipefail

# ---------------------------------------------------------------------------
# Validate input
# ---------------------------------------------------------------------------
if [[ $# -lt 1 ]]; then
  echo "❌ Usage: $0 <RESOURCE_GROUP_NAME>"
  echo "   Example: $0 1-a1b2c3d4-playground-sandbox"
  exit 1
fi

RG_NAME="$1"
LOCATION="centralus"
SA_NAME="tfstate$(date +%s | tail -c 11)"  # Unique, max 24 chars
CONTAINER_NAME="tfstate"

echo "╔══════════════════════════════════════════════════════════════╗"
echo "║  Bootstrapping Terraform Backend                           ║"
echo "╠══════════════════════════════════════════════════════════════╣"
echo "║  Resource Group : ${RG_NAME}"
echo "║  Storage Account: ${SA_NAME}"
echo "║  Container      : ${CONTAINER_NAME}"
echo "║  Location       : ${LOCATION}"
echo "╚══════════════════════════════════════════════════════════════╝"

# ---------------------------------------------------------------------------
# Verify the RG exists
# ---------------------------------------------------------------------------
echo ""
echo "🔍 Checking resource group exists..."
if ! az group show --name "${RG_NAME}" --output none 2>/dev/null; then
  echo "❌ Resource group '${RG_NAME}' not found."
  echo "   Make sure you copied the correct name from the KodeKloud Playground UI."
  exit 1
fi
echo "✅ Resource group '${RG_NAME}' found."

# ---------------------------------------------------------------------------
# Create Storage Account (idempotent)
# ---------------------------------------------------------------------------
echo ""
echo "📦 Creating storage account '${SA_NAME}'..."
az storage account create \
  --name "${SA_NAME}" \
  --resource-group "${RG_NAME}" \
  --location "${LOCATION}" \
  --sku "Standard_LRS" \
  --kind "StorageV2" \
  --min-tls-version "TLS1_2" \
  --allow-blob-public-access false \
  --output none

echo "✅ Storage account created."

# ---------------------------------------------------------------------------
# Create blob container
# ---------------------------------------------------------------------------
echo ""
echo "📂 Creating blob container '${CONTAINER_NAME}'..."
az storage container create \
  --name "${CONTAINER_NAME}" \
  --account-name "${SA_NAME}" \
  --auth-mode login \
  --output none

echo "✅ Container created."

# ---------------------------------------------------------------------------
# Print backend config flags
# ---------------------------------------------------------------------------
echo ""
echo "╔══════════════════════════════════════════════════════════════╗"
echo "║  ✅ BACKEND READY — Use these flags with terraform init:   ║"
echo "╚══════════════════════════════════════════════════════════════╝"
echo ""
echo "  cd terraform/"
echo "  terraform init -reconfigure \\"
echo "    -backend-config=\"resource_group_name=${RG_NAME}\" \\"
echo "    -backend-config=\"storage_account_name=${SA_NAME}\" \\"
echo "    -backend-config=\"container_name=${CONTAINER_NAME}\" \\"
echo "    -backend-config=\"key=aks-cicd-kit.tfstate\""
echo ""
echo "  terraform apply"
echo ""

# Also write a backend.hcl for convenience
BACKEND_HCL="../terraform/backend.hcl"
cat > "${BACKEND_HCL}" <<EOF
resource_group_name  = "${RG_NAME}"
storage_account_name = "${SA_NAME}"
container_name       = "${CONTAINER_NAME}"
key                  = "aks-cicd-kit.tfstate"
EOF

echo "💾 Also saved to terraform/backend.hcl — you can use:"
echo "   terraform init -reconfigure -backend-config=backend.hcl"
echo ""
