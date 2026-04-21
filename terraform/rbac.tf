# =============================================================================
# RBAC — Role Assignments (RG/resource-scoped ONLY — never subscription)
# =============================================================================
# The KodeKloud sandbox does NOT grant subscription-level permissions.
# Every role assignment here is scoped to the resource group or a specific
# resource ID. If you see "AuthorizationFailed" errors, confirm the scope
# is NOT /subscriptions/...
# =============================================================================

# ---------------------------------------------------------------------------
# AcrPull → AKS kubelet identity → scoped to ACR
# ---------------------------------------------------------------------------
# The kubelet identity is auto-created with the cluster and used by nodes
# to pull images. We give it AcrPull on the ACR resource.
resource "azurerm_role_assignment" "acr_pull" {
  scope                = azurerm_container_registry.acr.id
  role_definition_name = "AcrPull"
  principal_id         = azurerm_kubernetes_cluster.aks.kubelet_identity[0].object_id

  # Prevent destroy/recreate race conditions
  depends_on = [
    azurerm_kubernetes_cluster.aks,
    azurerm_container_registry.acr,
  ]
}

# ---------------------------------------------------------------------------
# Key Vault Secrets User → KV CSI addon identity → scoped to Key Vault
# ---------------------------------------------------------------------------
# The Key Vault CSI addon creates its own managed identity. We grant it
# read access to secrets so it can mount them into pods.
resource "azurerm_role_assignment" "kv_csi_secrets_user" {
  scope                = azurerm_key_vault.kv.id
  role_definition_name = "Key Vault Secrets User"
  principal_id         = azurerm_kubernetes_cluster.aks.key_vault_secrets_provider[0].secret_identity[0].object_id

  depends_on = [
    azurerm_kubernetes_cluster.aks,
    azurerm_key_vault.kv,
  ]
}

# ---------------------------------------------------------------------------
# Network Contributor → AKS system identity → scoped to AKS subnet
# ---------------------------------------------------------------------------
# Kubenet requires the cluster identity to manage routes on the subnet.
resource "azurerm_role_assignment" "aks_network_contributor" {
  scope                = azurerm_subnet.aks.id
  role_definition_name = "Network Contributor"
  principal_id         = azurerm_kubernetes_cluster.aks.identity[0].principal_id

  depends_on = [
    azurerm_kubernetes_cluster.aks,
    azurerm_subnet.aks,
  ]
}
