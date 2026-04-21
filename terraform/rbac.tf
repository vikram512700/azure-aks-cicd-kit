# =============================================================================
# RBAC — DISABLED for KodeKloud Sandbox
# =============================================================================
# The KodeKloud playground does NOT allow creating role assignments — even
# at resource or RG scope. The error is:
#   "does not have authorization to perform action
#    'Microsoft.Authorization/roleAssignments/read'"
#
# Workarounds used instead:
#   - ACR: admin_enabled = true (admin credentials for image pull)
#   - Key Vault: access_policy blocks inside the azurerm_key_vault resource
#   - AKS → ACR: attached post-apply via `az aks update --attach-acr`
#
# If your environment DOES allow role assignments, uncomment the blocks below.
# =============================================================================

# # AcrPull → AKS kubelet identity → scoped to ACR
# resource "azurerm_role_assignment" "acr_pull" {
#   scope                = azurerm_container_registry.acr.id
#   role_definition_name = "AcrPull"
#   principal_id         = azurerm_kubernetes_cluster.aks.kubelet_identity[0].object_id
# }

# # Key Vault Secrets User → KV CSI addon identity → scoped to Key Vault
# resource "azurerm_role_assignment" "kv_csi_secrets_user" {
#   scope                = azurerm_key_vault.kv.id
#   role_definition_name = "Key Vault Secrets User"
#   principal_id         = azurerm_kubernetes_cluster.aks.key_vault_secrets_provider[0].secret_identity[0].object_id
# }

# # Network Contributor → AKS system identity → scoped to AKS subnet
# resource "azurerm_role_assignment" "aks_network_contributor" {
#   scope                = azurerm_subnet.aks.id
#   role_definition_name = "Network Contributor"
#   principal_id         = azurerm_kubernetes_cluster.aks.identity[0].principal_id
# }
