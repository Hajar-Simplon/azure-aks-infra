variable "name_prefix" { type = string }
variable "unique_suffix" { type = string }
variable "location" { type = string }
variable "resource_group_name" { type = string }
variable "employee_group_object_id" {
  type     = string
  default  = null
  nullable = true
}
variable "tags" { type = map(string) }

locals {
  account_name = substr(replace("st${var.name_prefix}${var.unique_suffix}", "-", ""), 0, 24)
}

resource "azurerm_storage_account" "this" {
  name                            = local.account_name
  resource_group_name             = var.resource_group_name
  location                        = var.location
  account_tier                    = "Standard"
  account_replication_type        = "LRS"
  account_kind                    = "StorageV2"
  min_tls_version                 = "TLS1_2"
  https_traffic_only_enabled      = true
  allow_nested_items_to_be_public = false
  shared_access_key_enabled       = true

  blob_properties {
    versioning_enabled = true
    delete_retention_policy {
      days = 7
    }
    container_delete_retention_policy {
      days = 7
    }
  }

  share_properties {
    retention_policy {
      days = 7
    }
    smb {
      versions                        = ["SMB3.1.1"]
      authentication_types            = ["Kerberos"]
      kerberos_ticket_encryption_type = ["AES-256"]
      channel_encryption_type         = ["AES-256-GCM"]
    }
  }

  tags = var.tags
}

resource "azurerm_storage_share" "employees" {
  name               = "employees"
  storage_account_id = azurerm_storage_account.this.id
  quota              = 100
  access_tier        = "Hot"
}

resource "azurerm_storage_container" "aks_backup" {
  name                  = "aks-backup"
  storage_account_id    = azurerm_storage_account.this.id
  container_access_type = "private"
}

resource "azurerm_role_assignment" "employees" {
  count = var.employee_group_object_id == null ? 0 : 1

  scope                = azurerm_storage_account.this.id
  role_definition_name = "Storage File Data SMB Share Contributor"
  principal_id         = var.employee_group_object_id
}

output "id" { value = azurerm_storage_account.this.id }
output "name" { value = azurerm_storage_account.this.name }
output "primary_blob_endpoint" { value = azurerm_storage_account.this.primary_blob_endpoint }
output "employee_share_name" { value = azurerm_storage_share.employees.name }
output "backup_container_name" { value = azurerm_storage_container.aks_backup.name }
