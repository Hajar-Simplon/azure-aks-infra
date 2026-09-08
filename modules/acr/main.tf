variable "name_prefix" { type = string }
variable "unique_suffix" { type = string }
variable "location" { type = string }
variable "resource_group_name" { type = string }
variable "tags" { type = map(string) }

locals {
  registry_name = substr(replace("${var.name_prefix}${var.unique_suffix}", "-", ""), 0, 50)
}

resource "azurerm_container_registry" "this" {
  name                = local.registry_name
  resource_group_name = var.resource_group_name
  location            = var.location
  sku                 = "Basic"
  admin_enabled       = false
  tags                = var.tags
}

output "id" { value = azurerm_container_registry.this.id }
output "name" { value = azurerm_container_registry.this.name }
output "login_server" { value = azurerm_container_registry.this.login_server }
