variable "name_prefix" { type = string }
variable "unique_suffix" { type = string }
variable "location" { type = string }
variable "resource_group_name" { type = string }
variable "tenant_id" { type = string }
variable "tags" { type = map(string) }

locals {
  vault_name = substr("kv-${var.name_prefix}-${var.unique_suffix}", 0, 24)
}

resource "azurerm_key_vault" "this" {
  name                          = local.vault_name
  location                      = var.location
  resource_group_name           = var.resource_group_name
  tenant_id                     = var.tenant_id
  sku_name                      = "standard"
  rbac_authorization_enabled    = true
  purge_protection_enabled      = true
  soft_delete_retention_days    = 7
  public_network_access_enabled = true
  tags                          = var.tags
}

output "id" { value = azurerm_key_vault.this.id }
output "name" { value = azurerm_key_vault.this.name }
output "vault_uri" { value = azurerm_key_vault.this.vault_uri }
