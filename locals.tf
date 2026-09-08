locals {
  name_prefix = lower("${var.project_name}-${var.environment}")
  common_tags = merge({
    environment = var.environment
    managed_by  = "terraform"
    owner       = "hmezouar"
    project     = "aks-evaluation"
  }, var.tags)
}

resource "random_string" "suffix" {
  length  = 5
  upper   = false
  special = false
}
