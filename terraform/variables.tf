# =============================================================================
# Variables — Azure AKS CI/CD Kit (KodeKloud Playground)
# =============================================================================
# resource_group_name has NO default — you MUST paste the playground RG name
# into terraform.tfvars every new 3-hour session.
# =============================================================================

# ---------------------------------------------------------------------------
# Resource Group (pre-existing, changes every lab session)
# ---------------------------------------------------------------------------
variable "resource_group_name" {
  description = "Name of the pre-existing KodeKloud Playground resource group. Paste from the lab UI each session."
  type        = string
  nullable    = false
  # No default — forces explicit input every session

  validation {
    condition     = length(var.resource_group_name) > 0
    error_message = "resource_group_name cannot be empty. Copy it from the KodeKloud Playground UI."
  }
}

# ---------------------------------------------------------------------------
# Location — restricted to playground-supported regions
# ---------------------------------------------------------------------------
variable "location" {
  description = "Azure region. KodeKloud Playground typically supports Central US."
  type        = string
  default     = "Central US"

  validation {
    condition     = contains(["West US", "East US", "Central US", "South Central US"], var.location)
    error_message = "Location must be one of: West US, East US, Central US, South Central US."
  }
}

# ---------------------------------------------------------------------------
# Naming prefix — keeps resource names unique per session
# ---------------------------------------------------------------------------
variable "prefix" {
  description = "Short prefix for all resource names (lowercase, no special chars)."
  type        = string
  default     = "akscicd"

  validation {
    condition     = can(regex("^[a-z0-9]{3,12}$", var.prefix))
    error_message = "Prefix must be 3-12 lowercase alphanumeric characters."
  }
}

# ---------------------------------------------------------------------------
# AKS
# ---------------------------------------------------------------------------
variable "cluster_name" {
  description = "AKS cluster name."
  type        = string
  default     = "aks-cicd-cluster"
}

variable "kubernetes_version" {
  description = "Kubernetes version for AKS. Leave null for latest."
  type        = string
  default     = null
}

variable "node_count" {
  description = "Number of nodes in the default node pool."
  type        = number
  default     = 2
}

variable "node_vm_size" {
  description = "VM size for AKS nodes."
  type        = string
  default     = "Standard_D2s_v3"
}

# ---------------------------------------------------------------------------
# ACR
# ---------------------------------------------------------------------------
variable "acr_name" {
  description = "Azure Container Registry name (must be globally unique, alphanumeric only)."
  type        = string
  default     = null # Auto-generated from prefix if null
}

# ---------------------------------------------------------------------------
# Key Vault
# ---------------------------------------------------------------------------
variable "keyvault_name" {
  description = "Key Vault name (must be globally unique)."
  type        = string
  default     = null # Auto-generated from prefix if null
}

variable "python_app_secret" {
  description = "Value for the python-app-secret stored in Key Vault."
  type        = string
  default     = "python-secret-value-from-keyvault"
  sensitive   = true
}

variable "nodejs_app_secret" {
  description = "Value for the nodejs-app-secret stored in Key Vault."
  type        = string
  default     = "nodejs-secret-value-from-keyvault"
  sensitive   = true
}

# ---------------------------------------------------------------------------
# Tags
# ---------------------------------------------------------------------------
variable "tags" {
  description = "Tags applied to all resources."
  type        = map(string)
  default = {
    project     = "azure-aks-cicd-kit"
    environment = "sandbox"
    managed_by  = "terraform"
  }
}
