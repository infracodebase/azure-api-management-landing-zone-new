locals {
  # Naming convention
  resource_suffix = "${var.organization}-${var.environment}"

  # Resource names
  resource_group_name = "rg-apim-lz-${local.resource_suffix}"
  vnet_name           = "vnet-apim-lz-${local.resource_suffix}"
  apim_subnet_name    = "snet-apim-${local.resource_suffix}"
  appgw_subnet_name   = "snet-appgw-${local.resource_suffix}"
  backend_subnet_name = "snet-backend-${local.resource_suffix}"
  apim_nsg_name       = "nsg-apim-${local.resource_suffix}"
  appgw_nsg_name      = "nsg-appgw-${local.resource_suffix}"
  backend_nsg_name    = "nsg-backend-${local.resource_suffix}"
  key_vault_name      = "kv-apim-${var.organization}${var.environment}${random_string.suffix.result}"
  apim_name           = "apim-${local.resource_suffix}"
  appgw_name          = "appgw-${local.resource_suffix}"
  log_analytics_name  = "log-apim-lz-${local.resource_suffix}"
  app_insights_name   = "appi-apim-lz-${local.resource_suffix}"

  # Combined tags
  common_tags = merge(var.tags, {
    "Terraform"   = "true"
    "Environment" = var.environment
    "Location"    = var.location
  })
}