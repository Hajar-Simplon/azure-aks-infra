output "resource_group_name" {
  value       = data.azurerm_resource_group.existing.name
  description = "Existing resource group referenced by Terraform."
}

output "aks_cluster_name" {
  value       = module.aks.name
  description = "AKS cluster name."
}

output "aks_oidc_issuer_url" {
  value       = module.aks.oidc_issuer_url
  description = "OIDC issuer used by AKS Workload Identity."
}

output "postgres_workload_identity_client_id" {
  value       = module.aks.postgres_identity_client_id
  description = "Client ID to annotate the PostgreSQL Kubernetes ServiceAccount."
}

output "key_vault_name" {
  value       = module.key_vault.name
  description = "Vault used by the application-side SecretProviderClass."
}

output "employee_file_share_name" {
  value       = module.storage.employee_share_name
  description = "Azure Files SMB share for employees; not used by PostgreSQL."
}

output "backup_vault_name" {
  value       = module.backup.vault_name
  description = "Data Protection vault protecting the database namespace."
}
