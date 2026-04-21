# =============================================================================
# Main — AKS, ACR, Key Vault, Log Analytics (inside existing RG)
# =============================================================================
# Everything references data.azurerm_resource_group.existing — never creates an RG.
#
# SANDBOX NOTE: KodeKloud does NOT allow role assignments (even resource-scoped).
# So we use:
#   - ACR admin credentials (admin_enabled = true) for image pull
#   - Key Vault access policies (not RBAC mode) for secret access
# =============================================================================

# ---------------------------------------------------------------------------
# Data source — the pre-existing playground resource group
# ---------------------------------------------------------------------------
data "azurerm_resource_group" "existing" {
  name = var.resource_group_name
}

# Current Azure client (for Key Vault access policies)
data "azurerm_client_config" "current" {}

# ---------------------------------------------------------------------------
# Locals — computed names
# ---------------------------------------------------------------------------
locals {
  acr_name      = var.acr_name != null ? var.acr_name : "${var.prefix}acr${random_string.suffix.result}"
  keyvault_name = var.keyvault_name != null ? var.keyvault_name : "${var.prefix}kv${random_string.suffix.result}"
}

# ---------------------------------------------------------------------------
# Log Analytics Workspace (optional — for AKS monitoring)
# ---------------------------------------------------------------------------
resource "azurerm_log_analytics_workspace" "aks" {
  name                = "${var.prefix}-law"
  location            = data.azurerm_resource_group.existing.location
  resource_group_name = data.azurerm_resource_group.existing.name
  sku                 = "PerGB2018"
  retention_in_days   = 30
  tags                = var.tags
}

# ---------------------------------------------------------------------------
# Azure Container Registry — Basic SKU, admin enabled (sandbox workaround)
# ---------------------------------------------------------------------------
resource "azurerm_container_registry" "acr" {
  name                = local.acr_name
  resource_group_name = data.azurerm_resource_group.existing.name
  location            = data.azurerm_resource_group.existing.location
  sku                 = "Basic"
  admin_enabled       = true  # Sandbox can't do role assignments — use admin creds
  tags                = var.tags
}

# ---------------------------------------------------------------------------
# Azure Kubernetes Service — 1 pool, 2 nodes, D2s_v3, Kubenet
# ---------------------------------------------------------------------------
resource "azurerm_kubernetes_cluster" "aks" {
  name                = var.cluster_name
  location            = data.azurerm_resource_group.existing.location
  resource_group_name = data.azurerm_resource_group.existing.name
  dns_prefix          = var.prefix
  kubernetes_version  = var.kubernetes_version

  # --- Default Node Pool ---
  default_node_pool {
    name                        = "default"
    node_count                  = var.node_count
    vm_size                     = var.node_vm_size
    vnet_subnet_id              = azurerm_subnet.aks.id
    os_disk_size_gb             = 30
    type                        = "VirtualMachineScaleSets"
    temporary_name_for_rotation = "tmpdefault"
    tags                        = var.tags
  }

  # --- Identity — system-assigned (no SP needed) ---
  identity {
    type = "SystemAssigned"
  }

  # --- Network profile — Kubenet ---
  network_profile {
    network_plugin = "kubenet"
    dns_service_ip = "10.2.0.10"
    service_cidr   = "10.2.0.0/24"
    pod_cidr       = "10.244.0.0/16"
  }

  # --- OIDC issuer ---
  oidc_issuer_enabled = true

  # --- Key Vault CSI addon ---
  key_vault_secrets_provider {
    secret_rotation_enabled  = true
    secret_rotation_interval = "2m"
  }

  # --- Monitoring ---
  oms_agent {
    log_analytics_workspace_id = azurerm_log_analytics_workspace.aks.id
  }

  tags = var.tags
}

# ---------------------------------------------------------------------------
# Azure Key Vault — Standard SKU, Access Policy mode (not RBAC)
# ---------------------------------------------------------------------------
resource "azurerm_key_vault" "kv" {
  name                       = local.keyvault_name
  location                   = data.azurerm_resource_group.existing.location
  resource_group_name        = data.azurerm_resource_group.existing.name
  tenant_id                  = data.azurerm_client_config.current.tenant_id
  sku_name                   = "standard"
  enable_rbac_authorization  = false  # Sandbox can't assign RBAC roles — use access policies
  purge_protection_enabled   = false
  soft_delete_retention_days = 7
  tags                       = var.tags

  # Access policy for the current user (you running Terraform) — full secret access
  access_policy {
    tenant_id = data.azurerm_client_config.current.tenant_id
    object_id = data.azurerm_client_config.current.object_id

    secret_permissions = [
      "Get",
      "List",
      "Set",
      "Delete",
      "Purge",
      "Recover",
    ]
  }
}

# ---------------------------------------------------------------------------
# Seed Key Vault with app secrets
# ---------------------------------------------------------------------------
resource "azurerm_key_vault_secret" "python_app_secret" {
  name         = "python-app-secret"
  value        = var.python_app_secret
  key_vault_id = azurerm_key_vault.kv.id
  tags         = var.tags
}

resource "azurerm_key_vault_secret" "nodejs_app_secret" {
  name         = "nodejs-app-secret"
  value        = var.nodejs_app_secret
  key_vault_id = azurerm_key_vault.kv.id
  tags         = var.tags
}
