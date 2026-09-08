variable "name_prefix" { type = string }
variable "location" { type = string }
variable "resource_group_name" { type = string }
variable "subnet_id" { type = string }
variable "node_vm_size" { type = string }
variable "node_count" { type = number }
variable "acr_id" { type = string }
variable "key_vault_id" { type = string }
variable "key_vault_tenant_id" { type = string }
variable "postgres_namespace" { type = string }
variable "postgres_service_account" { type = string }
variable "tags" { type = map(string) }

resource "azurerm_user_assigned_identity" "postgres" {
  name                = "id-${var.name_prefix}-postgres"
  location            = var.location
  resource_group_name = var.resource_group_name
  tags                = var.tags
}

resource "azurerm_kubernetes_cluster" "this" {
  name                = "aks-${var.name_prefix}"
  location            = var.location
  resource_group_name = var.resource_group_name
  dns_prefix          = "aks-${var.name_prefix}"
  sku_tier            = "Free"

  role_based_access_control_enabled = true
  local_account_disabled            = false
  oidc_issuer_enabled               = true
  workload_identity_enabled         = true

  default_node_pool {
    name                         = "system"
    vm_size                      = var.node_vm_size
    node_count                   = var.node_count
    vnet_subnet_id               = var.subnet_id
    os_disk_size_gb              = 64
    os_disk_type                 = "Managed"
    only_critical_addons_enabled = false
    upgrade_settings {
      max_surge = "10%"
    }
  }

  identity {
    type = "SystemAssigned"
  }

  key_vault_secrets_provider {
    secret_rotation_enabled  = true
    secret_rotation_interval = "2m"
  }

  network_profile {
    network_plugin      = "azure"
    network_plugin_mode = "overlay"
    network_data_plane  = "cilium"
    network_policy      = "cilium"
    load_balancer_sku   = "standard"
    outbound_type       = "loadBalancer"
    pod_cidr            = "10.244.0.0/16"
    service_cidr        = "10.0.0.0/16"
    dns_service_ip      = "10.0.0.10"
  }

  storage_profile {
    disk_driver_enabled         = true
    file_driver_enabled         = true
    snapshot_controller_enabled = true
  }

  tags = var.tags

  lifecycle {
    precondition {
      condition     = var.location == "francecentral"
      error_message = "This evaluated design was quota-checked only for francecentral."
    }
  }
}

resource "azurerm_role_assignment" "acr_pull" {
  scope                = var.acr_id
  role_definition_name = "AcrPull"
  principal_id         = azurerm_kubernetes_cluster.this.kubelet_identity[0].object_id
}

resource "azurerm_federated_identity_credential" "postgres" {
  name      = "fic-${var.name_prefix}-postgres"
  audience  = ["api://AzureADTokenExchange"]
  issuer    = azurerm_kubernetes_cluster.this.oidc_issuer_url
  parent_id = azurerm_user_assigned_identity.postgres.id
  subject   = "system:serviceaccount:${var.postgres_namespace}:${var.postgres_service_account}"
}

resource "azurerm_role_assignment" "postgres_key_vault" {
  scope                = var.key_vault_id
  role_definition_name = "Key Vault Secrets User"
  principal_id         = azurerm_user_assigned_identity.postgres.principal_id
}

output "id" { value = azurerm_kubernetes_cluster.this.id }
output "name" { value = azurerm_kubernetes_cluster.this.name }
output "principal_id" { value = azurerm_kubernetes_cluster.this.identity[0].principal_id }
output "oidc_issuer_url" { value = azurerm_kubernetes_cluster.this.oidc_issuer_url }
output "postgres_identity_client_id" { value = azurerm_user_assigned_identity.postgres.client_id }
