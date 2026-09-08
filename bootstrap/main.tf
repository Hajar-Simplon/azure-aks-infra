data "azurerm_resource_group" "existing" {
  name = var.resource_group_name
}

data "azurerm_client_config" "current" {}

resource "random_string" "suffix" {
  length  = 6
  upper   = false
  special = false
}

resource "azurerm_storage_account" "state" {
  name                            = "sthmezouartf${random_string.suffix.result}"
  resource_group_name             = data.azurerm_resource_group.existing.name
  location                        = var.location
  account_tier                    = "Standard"
  account_replication_type        = "LRS"
  min_tls_version                 = "TLS1_2"
  https_traffic_only_enabled      = true
  allow_nested_items_to_be_public = false
  shared_access_key_enabled       = false

  blob_properties {
    versioning_enabled = true
    delete_retention_policy {
      days = 7
    }
    container_delete_retention_policy {
      days = 7
    }
  }

  tags = {
    environment = "eval"
    managed_by  = "terraform-bootstrap"
    owner       = "hmezouar"
    project     = "aks-lab"
  }
}

resource "azurerm_storage_container" "state" {
  name                  = "tfstate"
  storage_account_id    = azurerm_storage_account.state.id
  container_access_type = "private"
}

resource "azurerm_role_assignment" "current_user_state_access" {
  scope                = azurerm_storage_account.state.id
  role_definition_name = "Storage Blob Data Contributor"
  principal_id         = data.azurerm_client_config.current.object_id
}

output "backend_init_command" {
  value = "terraform init -backend-config=resource_group_name=${data.azurerm_resource_group.existing.name} -backend-config=storage_account_name=${azurerm_storage_account.state.name} -backend-config=container_name=${azurerm_storage_container.state.name} -backend-config=key=aks-lab.tfstate"
}

output "storage_account_name" { value = azurerm_storage_account.state.name }
