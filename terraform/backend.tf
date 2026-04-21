# =============================================================================
# Backend — Remote State in Azure Storage (same RG)
# =============================================================================
# Partial configuration — supply values via -backend-config flags or a
# backend.hcl file. The bootstrap-backend.sh script prints the exact flags.
#
# Usage:
#   terraform init -reconfigure \
#     -backend-config="resource_group_name=<RG_NAME>" \
#     -backend-config="storage_account_name=<SA_NAME>" \
#     -backend-config="container_name=tfstate" \
#     -backend-config="key=aks-cicd-kit.tfstate"
# =============================================================================

terraform {
  backend "azurerm" {
    # These are supplied at init time — do NOT hard-code them.
    # resource_group_name  = "..."
    # storage_account_name = "..."
    container_name = "tfstate"
    key            = "aks-cicd-kit.tfstate"
  }
}
