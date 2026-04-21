# =============================================================================
# Providers — Azure AKS CI/CD Kit
# =============================================================================
# azurerm ~> 4.0 with skip_provider_registration to avoid permission errors
# in the KodeKloud sandbox.
# =============================================================================

terraform {
  required_version = ">= 1.5.0"

  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 4.0"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.6"
    }
  }
}

provider "azurerm" {
  features {
    key_vault {
      # Purge protection is off in sandbox — allow immediate delete
      purge_soft_delete_on_destroy    = true
      recover_soft_deleted_key_vaults = true
    }
    resource_group {
      # Never let Terraform try to delete the playground RG
      prevent_deletion_if_contains_resources = false
    }
  }

  # Sandbox may not allow provider registration — skip it
  resource_provider_registrations = "none"
}

# Random suffix for globally-unique resource names (ACR, Key Vault, Storage)
resource "random_string" "suffix" {
  length  = 6
  special = false
  upper   = false
}
