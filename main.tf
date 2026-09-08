module "network" {
  source = "./modules/network"

  name_prefix         = local.name_prefix
  location            = var.location
  resource_group_name = data.azurerm_resource_group.existing.name
  tags                = local.common_tags
}

module "acr" {
  source = "./modules/acr"

  name_prefix         = local.name_prefix
  unique_suffix       = random_string.suffix.result
  location            = var.location
  resource_group_name = data.azurerm_resource_group.existing.name
  tags                = local.common_tags
}

module "key_vault" {
  source = "./modules/key-vault"

  name_prefix         = local.name_prefix
  unique_suffix       = random_string.suffix.result
  location            = var.location
  resource_group_name = data.azurerm_resource_group.existing.name
  tenant_id           = data.azurerm_client_config.current.tenant_id
  tags                = local.common_tags
}

module "aks" {
  source = "./modules/aks"

  name_prefix                = local.name_prefix
  location                   = var.location
  resource_group_name        = data.azurerm_resource_group.existing.name
  subnet_id                  = module.network.aks_subnet_id
  node_vm_size               = var.node_vm_size
  node_count                 = var.node_count
  acr_id                     = module.acr.id
  key_vault_id               = module.key_vault.id
  key_vault_tenant_id        = data.azurerm_client_config.current.tenant_id
  postgres_namespace         = "database"
  postgres_restore_namespace = "database-restore"
  postgres_service_account   = "postgres-workload"
  tags                       = local.common_tags
}

module "storage" {
  source = "./modules/storage"

  name_prefix              = local.name_prefix
  unique_suffix            = random_string.suffix.result
  location                 = var.location
  resource_group_name      = data.azurerm_resource_group.existing.name
  employee_group_object_id = var.employee_group_object_id
  tags                     = local.common_tags
}

module "backup" {
  source = "./modules/backup"

  name_prefix              = local.name_prefix
  location                 = var.location
  resource_group_name      = data.azurerm_resource_group.existing.name
  resource_group_id        = data.azurerm_resource_group.existing.id
  subscription_id          = var.subscription_id
  tenant_id                = data.azurerm_client_config.current.tenant_id
  aks_cluster_id           = module.aks.id
  aks_cluster_principal_id = module.aks.principal_id
  storage_account_id       = module.storage.id
  storage_account_name     = module.storage.name
  storage_blob_endpoint    = module.storage.primary_blob_endpoint
  backup_container_name    = module.storage.backup_container_name
  included_namespace       = "database"
  tags                     = local.common_tags
}
