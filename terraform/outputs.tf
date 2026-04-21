# =============================================================================
# Outputs — Azure AKS CI/CD Kit
# =============================================================================

# ---------------------------------------------------------------------------
# AKS
# ---------------------------------------------------------------------------
output "aks_cluster_name" {
  description = "AKS cluster name."
  value       = azurerm_kubernetes_cluster.aks.name
}

output "aks_get_credentials_command" {
  description = "Run this to configure kubectl."
  value       = "az aks get-credentials --resource-group ${data.azurerm_resource_group.existing.name} --name ${azurerm_kubernetes_cluster.aks.name} --overwrite-existing"
}

# ---------------------------------------------------------------------------
# ACR
# ---------------------------------------------------------------------------
output "acr_login_server" {
  description = "ACR login server URL (use in Docker push/pull)."
  value       = azurerm_container_registry.acr.login_server
}

output "acr_name" {
  description = "ACR name."
  value       = azurerm_container_registry.acr.name
}

output "acr_admin_username" {
  description = "ACR admin username (for Docker login in sandbox)."
  value       = azurerm_container_registry.acr.admin_username
  sensitive   = true
}

output "acr_admin_password" {
  description = "ACR admin password (for Docker login in sandbox)."
  value       = azurerm_container_registry.acr.admin_password
  sensitive   = true
}

# ---------------------------------------------------------------------------
# Key Vault
# ---------------------------------------------------------------------------
output "keyvault_uri" {
  description = "Key Vault URI."
  value       = azurerm_key_vault.kv.vault_uri
}

output "keyvault_name" {
  description = "Key Vault name."
  value       = azurerm_key_vault.kv.name
}

output "kv_csi_identity_client_id" {
  description = "Client ID of the Key Vault CSI addon identity. Use in SecretProviderClass."
  value       = azurerm_kubernetes_cluster.aks.key_vault_secrets_provider[0].secret_identity[0].client_id
}

# ---------------------------------------------------------------------------
# Tenant
# ---------------------------------------------------------------------------
output "tenant_id" {
  description = "Azure tenant ID. Use in SecretProviderClass."
  value       = data.azurerm_client_config.current.tenant_id
}

# ---------------------------------------------------------------------------
# Quick-start
# ---------------------------------------------------------------------------
output "next_steps" {
  description = "What to do after terraform apply."
  value       = <<-EOT

    ====== NEXT STEPS ======

    1. Get AKS credentials:
       ${format("az aks get-credentials --resource-group %s --name %s --overwrite-existing", data.azurerm_resource_group.existing.name, azurerm_kubernetes_cluster.aks.name)}

    2. Attach ACR to AKS (sandbox workaround):
       ${format("az aks update --resource-group %s --name %s --attach-acr %s", data.azurerm_resource_group.existing.name, azurerm_kubernetes_cluster.aks.name, azurerm_container_registry.acr.name)}

    3. Add KV access policy for CSI addon:
       ${format("az keyvault set-policy --name %s --object-id %s --secret-permissions get list", azurerm_key_vault.kv.name, azurerm_kubernetes_cluster.aks.key_vault_secrets_provider[0].secret_identity[0].object_id)}

    4. Update k8s/secretproviderclass.yaml:
       userAssignedIdentityID: ${azurerm_kubernetes_cluster.aks.key_vault_secrets_provider[0].secret_identity[0].client_id}
       keyvaultName: ${azurerm_key_vault.kv.name}
       tenantId: ${data.azurerm_client_config.current.tenant_id}

    5. Install NGINX ingress + apply manifests:
       kubectl apply -f https://raw.githubusercontent.com/kubernetes/ingress-nginx/controller-v1.10.0/deploy/static/provider/cloud/deploy.yaml
       kubectl apply -f k8s/

  EOT
}
