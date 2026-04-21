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

output "aks_kubelet_identity_object_id" {
  description = "Object ID of the AKS kubelet managed identity (used for AcrPull)."
  value       = azurerm_kubernetes_cluster.aks.kubelet_identity[0].object_id
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
# Quick-start instructions
# ---------------------------------------------------------------------------
output "next_steps" {
  description = "What to do after terraform apply."
  value       = <<-EOT

    ╔══════════════════════════════════════════════════════════════╗
    ║                   NEXT STEPS                                ║
    ╠══════════════════════════════════════════════════════════════╣
    ║ 1. Get AKS credentials:                                    ║
    ║    az aks get-credentials \                                 ║
    ║      --resource-group ${data.azurerm_resource_group.existing.name} \
    ║      --name ${azurerm_kubernetes_cluster.aks.name}          ║
    ║                                                             ║
    ║ 2. Update k8s/secretproviderclass.yaml with:                ║
    ║    userAssignedIdentityID: ${azurerm_kubernetes_cluster.aks.key_vault_secrets_provider[0].secret_identity[0].client_id}
    ║    keyvaultName: ${azurerm_key_vault.kv.name}               ║
    ║    tenantId: ${data.azurerm_client_config.current.tenant_id}║
    ║                                                             ║
    ║ 3. Install NGINX ingress controller:                        ║
    ║    kubectl apply -f https://raw.githubusercontent.com/      ║
    ║      kubernetes/ingress-nginx/controller-v1.10.0/           ║
    ║      deploy/static/provider/cloud/deploy.yaml               ║
    ║                                                             ║
    ║ 4. Apply K8s manifests:                                     ║
    ║    kubectl apply -f k8s/                                    ║
    ║                                                             ║
    ║ 5. Push images to ACR:                                      ║
    ║    az acr login --name ${azurerm_container_registry.acr.name}║
    ║    docker build -t ${azurerm_container_registry.acr.login_server}/python-app:latest ./app-python
    ║    docker push ${azurerm_container_registry.acr.login_server}/python-app:latest
    ║                                                             ║
    ╚══════════════════════════════════════════════════════════════╝
  EOT
}
