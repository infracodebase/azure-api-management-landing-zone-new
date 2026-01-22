# Resource Group
output "resource_group_name" {
  description = "Name of the resource group"
  value       = azurerm_resource_group.this.name
}

output "resource_group_location" {
  description = "Location of the resource group"
  value       = azurerm_resource_group.this.location
}

# Virtual Network
output "virtual_network_name" {
  description = "Name of the virtual network"
  value       = azurerm_virtual_network.this.name
}

output "virtual_network_id" {
  description = "ID of the virtual network"
  value       = azurerm_virtual_network.this.id
}

# API Management
output "api_management_name" {
  description = "Name of the API Management instance"
  value       = azurerm_api_management.this.name
}

output "api_management_gateway_url" {
  description = "Gateway URL of API Management"
  value       = azurerm_api_management.this.gateway_url
}

output "api_management_portal_url" {
  description = "Developer portal URL of API Management"
  value       = azurerm_api_management.this.developer_portal_url
}

output "api_management_private_ip" {
  description = "Private IP addresses of API Management"
  value       = azurerm_api_management.this.private_ip_addresses
}

# Application Gateway
output "application_gateway_name" {
  description = "Name of the Application Gateway"
  value       = azurerm_application_gateway.this.name
}

output "application_gateway_public_ip" {
  description = "Public IP address of the Application Gateway"
  value       = azurerm_public_ip.appgw.ip_address
}

output "application_gateway_fqdn" {
  description = "FQDN of the Application Gateway"
  value       = azurerm_public_ip.appgw.fqdn
}

# Key Vault
output "key_vault_name" {
  description = "Name of the Key Vault"
  value       = azurerm_key_vault.this.name
}

output "key_vault_uri" {
  description = "URI of the Key Vault"
  value       = azurerm_key_vault.this.vault_uri
}

# Backend Services
output "app_service_name" {
  description = "Name of the backend App Service"
  value       = azurerm_linux_web_app.backend_api.name
}

output "app_service_hostname" {
  description = "Default hostname of the backend App Service"
  value       = azurerm_linux_web_app.backend_api.default_hostname
}

output "aks_cluster_name" {
  description = "Name of the AKS cluster"
  value       = azurerm_kubernetes_cluster.backend.name
}

output "aks_cluster_fqdn" {
  description = "FQDN of the AKS cluster"
  value       = azurerm_kubernetes_cluster.backend.private_fqdn
}

# Monitoring
output "log_analytics_workspace_name" {
  description = "Name of the Log Analytics workspace"
  value       = azurerm_log_analytics_workspace.this.name
}

output "log_analytics_workspace_id" {
  description = "ID of the Log Analytics workspace"
  value       = azurerm_log_analytics_workspace.this.workspace_id
}

output "application_insights_name" {
  description = "Name of Application Insights"
  value       = azurerm_application_insights.this.name
}

output "application_insights_instrumentation_key" {
  description = "Instrumentation key for Application Insights"
  value       = azurerm_application_insights.this.instrumentation_key
  sensitive   = true
}

output "application_insights_connection_string" {
  description = "Connection string for Application Insights"
  value       = azurerm_application_insights.this.connection_string
  sensitive   = true
}

# URLs and endpoints for easy access
output "api_gateway_https_url" {
  description = "HTTPS URL to access APIs through Application Gateway"
  value       = "https://${azurerm_public_ip.appgw.fqdn}"
}

output "developer_portal_url" {
  description = "Developer portal URL (via Application Gateway)"
  value       = "https://${azurerm_public_ip.appgw.fqdn}/developer"
}

# Configuration guidance
output "next_steps" {
  description = "Next steps for configuration"
  value       = <<-EOT
    # API Management Landing Zone Deployment Complete!

    ## Access URLs:
    - API Gateway: https://${azurerm_public_ip.appgw.fqdn}
    - Developer Portal: https://${azurerm_public_ip.appgw.fqdn}/developer
    - Azure Portal: https://portal.azure.com/#@/resource${azurerm_api_management.this.id}

    ## Next Steps:
    1. Configure custom domains in Application Gateway and API Management
    2. Import your APIs using the developer portal or Azure CLI
    3. Set up API policies for authentication, rate limiting, and transformation
    4. Configure backend services and health probes
    5. Set up Azure AD authentication for the developer portal
    6. Review monitoring alerts and dashboards in Azure Monitor

    ## AKS Configuration:
    - Connect to AKS: az aks get-credentials --resource-group ${azurerm_resource_group.this.name} --name ${azurerm_kubernetes_cluster.backend.name}

    ## Security Notes:
    - API Management is deployed in Internal VNET mode for security
    - All certificates are stored in Azure Key Vault
    - WAF protection is enabled on Application Gateway
    - Private endpoints are configured for secure access
    EOT
}