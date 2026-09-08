variable "name_prefix" { type = string }
variable "location" { type = string }
variable "resource_group_name" { type = string }
variable "resource_group_id" { type = string }
variable "subscription_id" { type = string }
variable "tenant_id" { type = string }
variable "aks_cluster_id" { type = string }
variable "aks_cluster_principal_id" { type = string }
variable "storage_account_id" { type = string }
variable "storage_account_name" { type = string }
variable "storage_blob_endpoint" { type = string }
variable "backup_container_name" { type = string }
variable "included_namespace" { type = string }
variable "tags" { type = map(string) }

resource "azurerm_data_protection_backup_vault" "this" {
  name                = "bv-${var.name_prefix}"
  resource_group_name = var.resource_group_name
  location            = var.location
  datastore_type      = "OperationalStore"
  redundancy          = "LocallyRedundant"

  identity {
    type = "SystemAssigned"
  }

  tags = var.tags
}

resource "azurerm_data_protection_backup_policy_kubernetes_cluster" "this" {
  name                = "bp-${var.name_prefix}-database"
  resource_group_name = var.resource_group_name
  vault_name          = azurerm_data_protection_backup_vault.this.name

  backup_repeating_time_intervals = ["R/2026-09-07T02:00:00+02:00/PT4H"]
  time_zone                       = "Romance Standard Time"

  default_retention_rule {
    life_cycle {
      duration        = "P7D"
      data_store_type = "OperationalStore"
    }
  }
}

resource "azurerm_kubernetes_cluster_trusted_access_role_binding" "backup" {
  kubernetes_cluster_id = var.aks_cluster_id
  name                  = "backup-operator"
  roles                 = ["Microsoft.DataProtection/backupVaults/backup-operator"]
  source_resource_id    = azurerm_data_protection_backup_vault.this.id
}

resource "azurerm_kubernetes_cluster_extension" "backup" {
  name           = "azure-aks-backup"
  cluster_id     = var.aks_cluster_id
  extension_type = "microsoft.dataprotection.kubernetes"

  configuration_settings = {
    "configuration.backupStorageLocation.bucket"                   = var.backup_container_name
    "configuration.backupStorageLocation.config.storageAccount"    = var.storage_account_name
    "configuration.backupStorageLocation.config.resourceGroup"     = var.resource_group_name
    "configuration.backupStorageLocation.config.subscriptionId"    = var.subscription_id
    "configuration.backupStorageLocation.config.useAAD"            = "true"
    "configuration.backupStorageLocation.config.storageAccountURI" = var.storage_blob_endpoint
    "credentials.tenantId"                                         = var.tenant_id
  }
}

resource "azurerm_role_assignment" "extension_blob" {
  scope                = var.storage_account_id
  role_definition_name = "Storage Blob Data Contributor"
  principal_id         = azurerm_kubernetes_cluster_extension.backup.aks_assigned_identity[0].principal_id
}

resource "azurerm_role_assignment" "vault_cluster_reader" {
  scope                = var.aks_cluster_id
  role_definition_name = "Reader"
  principal_id         = azurerm_data_protection_backup_vault.this.identity[0].principal_id
}

resource "azurerm_role_assignment" "vault_rg_reader" {
  scope                = var.resource_group_id
  role_definition_name = "Reader"
  principal_id         = azurerm_data_protection_backup_vault.this.identity[0].principal_id
}

resource "azurerm_role_assignment" "cluster_snapshot_contributor" {
  scope                = var.resource_group_id
  role_definition_name = "Contributor"
  principal_id         = var.aks_cluster_principal_id
}

resource "azurerm_data_protection_backup_instance_kubernetes_cluster" "this" {
  name                         = "bi-${var.name_prefix}-database"
  location                     = var.location
  vault_id                     = azurerm_data_protection_backup_vault.this.id
  kubernetes_cluster_id        = var.aks_cluster_id
  snapshot_resource_group_name = var.resource_group_name
  backup_policy_id             = azurerm_data_protection_backup_policy_kubernetes_cluster.this.id

  backup_datasource_parameters {
    excluded_namespaces              = []
    excluded_resource_types          = []
    cluster_scoped_resources_enabled = true
    included_namespaces              = [var.included_namespace]
    included_resource_types          = []
    label_selectors                  = []
    volume_snapshot_enabled          = true
  }

  depends_on = [
    azurerm_kubernetes_cluster_trusted_access_role_binding.backup,
    azurerm_role_assignment.extension_blob,
    azurerm_role_assignment.vault_cluster_reader,
    azurerm_role_assignment.vault_rg_reader,
    azurerm_role_assignment.cluster_snapshot_contributor,
  ]
}

output "vault_name" { value = azurerm_data_protection_backup_vault.this.name }
output "backup_instance_id" { value = azurerm_data_protection_backup_instance_kubernetes_cluster.this.id }
