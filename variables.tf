variable "subscription_id" {
  description = "Azure subscription ID."
  type        = string
  default     = "5e683e0f-b00c-48d6-9769-5aaf598de8f1"
}

variable "resource_group_name" {
  description = "Existing resource group. It is read as data and never managed by this state."
  type        = string
  default     = "hmezouarRG"
}

variable "location" {
  description = "Azure region for all new resources."
  type        = string
  default     = "francecentral"
}

variable "environment" {
  description = "Short environment label used in names and tags."
  type        = string
  default     = "eval"
}

variable "project_name" {
  description = "Short project identifier."
  type        = string
  default     = "hmezouar-aks"
}

variable "node_vm_size" {
  description = "AKS system node VM size. D2_v3 fits the verified France Central quota."
  type        = string
  default     = "Standard_D2_v3"
}

variable "node_count" {
  description = "POC node count. Increase for production availability."
  type        = number
  default     = 1

  validation {
    condition     = var.node_count >= 1 && var.node_count <= 3
    error_message = "node_count must be between 1 and 3 for this evaluation."
  }
}

variable "employee_group_object_id" {
  description = "Optional Entra group object ID that receives SMB Contributor on the employee storage account."
  type        = string
  default     = "b3038213-ba5b-4dd5-af8f-b4bbbd0da096"
  nullable    = true
}

variable "gitlab_project_path" {
  description = "Optional GitLab path (group/project) used later to create an OIDC federated credential."
  type        = string
  default     = null
  nullable    = true
}

variable "tags" {
  description = "Additional tags merged with mandatory project tags."
  type        = map(string)
  default     = {}
}
