# App Service Plan for backend services
resource "azurerm_service_plan" "backend" {
  name                = "asp-backend-${local.resource_suffix}"
  location            = azurerm_resource_group.this.location
  resource_group_name = azurerm_resource_group.this.name
  os_type             = "Linux"
  sku_name            = "P1v3"
  tags                = local.common_tags
}

# Sample App Service for backend API
resource "azurerm_linux_web_app" "backend_api" {
  name                = "app-backend-api-${local.resource_suffix}-${random_string.suffix.result}"
  location            = azurerm_resource_group.this.location
  resource_group_name = azurerm_resource_group.this.name
  service_plan_id     = azurerm_service_plan.backend.id

  site_config {
    always_on = true

    application_stack {
      dotnet_version = "6.0"
    }

    # Virtual network integration
    vnet_route_all_enabled = true
  }

  # App settings
  app_settings = {
    "ASPNETCORE_ENVIRONMENT" = var.environment
    "WEBSITE_VNET_ROUTE_ALL" = "1"
  }

  # Managed Identity
  identity {
    type = "SystemAssigned"
  }

  # Virtual Network Integration
  virtual_network_subnet_id = azurerm_subnet.backend.id

  tags = local.common_tags
}

# Private Endpoint for App Service
resource "azurerm_private_endpoint" "backend_api" {
  name                = "pe-${azurerm_linux_web_app.backend_api.name}"
  location            = azurerm_resource_group.this.location
  resource_group_name = azurerm_resource_group.this.name
  subnet_id           = azurerm_subnet.backend.id

  private_service_connection {
    name                           = "psc-${azurerm_linux_web_app.backend_api.name}"
    private_connection_resource_id = azurerm_linux_web_app.backend_api.id
    is_manual_connection           = false
    subresource_names              = ["sites"]
  }

  tags = local.common_tags
}

# Private DNS Zone for App Service
resource "azurerm_private_dns_zone" "app_service" {
  name                = "privatelink.azurewebsites.net"
  resource_group_name = azurerm_resource_group.this.name
  tags                = local.common_tags
}

# Link Private DNS Zone to Virtual Network
resource "azurerm_private_dns_zone_virtual_network_link" "app_service" {
  name                  = "dns-link-app-service"
  resource_group_name   = azurerm_resource_group.this.name
  private_dns_zone_name = azurerm_private_dns_zone.app_service.name
  virtual_network_id    = azurerm_virtual_network.this.id
  tags                  = local.common_tags
}

# Sample Azure Kubernetes Service (AKS) cluster for containerized backends
resource "azurerm_kubernetes_cluster" "backend" {
  name                = "aks-backend-${local.resource_suffix}"
  location            = azurerm_resource_group.this.location
  resource_group_name = azurerm_resource_group.this.name
  dns_prefix          = "aks-backend-${local.resource_suffix}"
  kubernetes_version  = "1.28"

  default_node_pool {
    name                = "system"
    node_count          = 2
    vm_size             = "Standard_D2s_v3"
    type                = "VirtualMachineScaleSets"
    auto_scaling_enabled = true
    min_count           = 1
    max_count           = 3
    vnet_subnet_id      = azurerm_subnet.backend.id

    # Enable Azure CNI for network integration
    enable_node_public_ip = false

    upgrade_settings {
      max_surge = "10%"
    }
  }

  # Enable managed identity
  identity {
    type = "SystemAssigned"
  }

  # Network profile for Azure CNI
  network_profile {
    network_plugin     = "azure"
    network_policy     = "azure"
    service_cidr       = "172.16.0.0/16"
    dns_service_ip     = "172.16.0.10"
    docker_bridge_cidr = "172.17.0.1/16"
  }

  # Private cluster configuration
  private_cluster_enabled = true
  private_dns_zone_id     = "System"

  # Azure AD integration
  azure_active_directory_role_based_access_control {
    managed            = true
    azure_rbac_enabled = true
  }

  # Monitoring
  oms_agent {
    log_analytics_workspace_id = azurerm_log_analytics_workspace.this.id
  }

  tags = local.common_tags
}

# API Management Backend for App Service
resource "azurerm_api_management_backend" "app_service" {
  name                = "backend-app-service"
  resource_group_name = azurerm_resource_group.this.name
  api_management_name = azurerm_api_management.this.name
  protocol            = "http"
  url                 = "https://${azurerm_linux_web_app.backend_api.default_hostname}"

  service_fabric_cluster {
    management_endpoints = ["https://${azurerm_linux_web_app.backend_api.default_hostname}"]
    max_partition_resolution_retries = 5
  }

  credentials {
    query = {
      "api-version" = "2023-05-01"
    }

    header = {
      "x-my-header" = "my-header-value"
    }
  }
}

# Sample API that uses the App Service backend
resource "azurerm_api_management_api" "backend_api" {
  name                  = "backend-api"
  resource_group_name   = azurerm_resource_group.this.name
  api_management_name   = azurerm_api_management.this.name
  revision              = "1"
  display_name          = "Backend API"
  path                  = "backend"
  protocols             = ["https"]
  service_url           = "https://${azurerm_linux_web_app.backend_api.default_hostname}"
  subscription_required = true

  # API policy to use the backend service
  import {
    content_format = "openapi"
    content_value = jsonencode({
      openapi = "3.0.0"
      info = {
        title   = "Backend API"
        version = "1.0"
      }
      paths = {
        "/health" = {
          get = {
            summary     = "Health check endpoint"
            operationId = "getHealth"
            responses = {
              "200" = {
                description = "Healthy"
                content = {
                  "application/json" = {
                    schema = {
                      type = "object"
                      properties = {
                        status = {
                          type = "string"
                        }
                        timestamp = {
                          type = "string"
                        }
                      }
                    }
                  }
                }
              }
            }
          }
        }
      }
    })
  }
}

# Associate Backend API with Product
resource "azurerm_api_management_product_api" "backend" {
  api_name            = azurerm_api_management_api.backend_api.name
  product_id          = azurerm_api_management_product.starter.product_id
  api_management_name = azurerm_api_management.this.name
  resource_group_name = azurerm_resource_group.this.name
}