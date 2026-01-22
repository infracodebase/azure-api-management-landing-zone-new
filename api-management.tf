# User Assigned Managed Identity for API Management
resource "azurerm_user_assigned_identity" "apim" {
  name                = "id-${local.apim_name}"
  location            = azurerm_resource_group.this.location
  resource_group_name = azurerm_resource_group.this.name
  tags                = local.common_tags
}

# Key Vault Access Policy for API Management Managed Identity
resource "azurerm_key_vault_access_policy" "apim" {
  key_vault_id = azurerm_key_vault.this.id
  tenant_id    = azurerm_user_assigned_identity.apim.tenant_id
  object_id    = azurerm_user_assigned_identity.apim.principal_id

  secret_permissions = [
    "Get", "List"
  ]

  certificate_permissions = [
    "Get", "List"
  ]
}

# API Management Instance
resource "azurerm_api_management" "this" {
  name                = local.apim_name
  location            = azurerm_resource_group.this.location
  resource_group_name = azurerm_resource_group.this.name
  publisher_name      = var.apim_publisher_name
  publisher_email     = var.apim_publisher_email
  sku_name            = var.apim_sku_name

  # Configure virtual network integration in Internal mode
  virtual_network_type = "Internal"
  virtual_network_configuration {
    subnet_id = azurerm_subnet.apim.id
  }

  # Managed Identity configuration
  identity {
    type         = "UserAssigned"
    identity_ids = [azurerm_user_assigned_identity.apim.id]
  }

  # Security settings
  min_api_version = "2019-12-01"

  # Global policy will be configured post-deployment via separate resource

  tags = local.common_tags

  depends_on = [
    azurerm_subnet_network_security_group_association.apim,
    azurerm_key_vault_access_policy.apim
  ]
}

# API Management Logger for Application Insights
resource "azurerm_api_management_logger" "app_insights" {
  name                = "app-insights-logger"
  api_management_name = azurerm_api_management.this.name
  resource_group_name = azurerm_resource_group.this.name

  application_insights {
    instrumentation_key = azurerm_application_insights.this.instrumentation_key
  }
}

# Sample API for demonstration
resource "azurerm_api_management_api" "echo" {
  name                  = "echo-api"
  resource_group_name   = azurerm_resource_group.this.name
  api_management_name   = azurerm_api_management.this.name
  revision              = "1"
  display_name          = "Echo API"
  path                  = "echo"
  protocols             = ["https"]
  service_url           = "http://echoapi.cloudapp.net/api"
  subscription_required = false

  import {
    content_format = "openapi"
    content_value  = file("${path.module}/api-definitions/echo-api.yaml")
  }
}

# API Management Product
resource "azurerm_api_management_product" "starter" {
  product_id            = "starter"
  api_management_name   = azurerm_api_management.this.name
  resource_group_name   = azurerm_resource_group.this.name
  display_name          = "Starter"
  description           = "Starter product for API consumers"
  subscription_required = true
  approval_required     = false
  published             = true
}

# Associate API with Product
resource "azurerm_api_management_product_api" "echo" {
  api_name            = azurerm_api_management_api.echo.name
  product_id          = azurerm_api_management_product.starter.product_id
  api_management_name = azurerm_api_management.this.name
  resource_group_name = azurerm_resource_group.this.name
}

# API Management Custom Domain (using Key Vault certificate)
resource "azurerm_api_management_custom_domain" "this" {
  api_management_id = azurerm_api_management.this.id

  gateway {
    host_name                       = "api.contoso.com"
    key_vault_id                    = azurerm_key_vault_certificate.api_ssl.secret_id
    negotiate_client_certificate    = false
    ssl_keyvault_identity_client_id = azurerm_user_assigned_identity.apim.client_id
  }

  developer_portal {
    host_name                       = "developer.contoso.com"
    key_vault_id                    = azurerm_key_vault_certificate.api_ssl.secret_id
    negotiate_client_certificate    = false
    ssl_keyvault_identity_client_id = azurerm_user_assigned_identity.apim.client_id
  }

  depends_on = [azurerm_key_vault_certificate.api_ssl]
}

# Global API Management Policy
resource "azurerm_api_management_policy" "global" {
  api_management_id = azurerm_api_management.this.id

  xml_content = <<XML
<policies>
  <inbound>
    <cors allow-credentials="false">
      <allowed-origins>
        <origin>*</origin>
      </allowed-origins>
      <allowed-methods>
        <method>GET</method>
        <method>POST</method>
        <method>PUT</method>
        <method>DELETE</method>
        <method>HEAD</method>
        <method>OPTIONS</method>
        <method>PATCH</method>
      </allowed-methods>
      <allowed-headers>
        <header>*</header>
      </allowed-headers>
    </cors>
    <set-header name="X-Forwarded-For" exists-action="override">
      <value>@(context.Request.IpAddress)</value>
    </set-header>
    <set-header name="X-Forwarded-Proto" exists-action="override">
      <value>https</value>
    </set-header>
  </inbound>
  <backend>
    <forward-request />
  </backend>
  <outbound>
    <set-header name="X-Powered-By" exists-action="delete" />
    <set-header name="Server" exists-action="delete" />
  </outbound>
  <on-error>
    <set-header name="ErrorSource" exists-action="override">
      <value>@(context.LastError.Source)</value>
    </set-header>
    <set-header name="ErrorReason" exists-action="override">
      <value>@(context.LastError.Reason)</value>
    </set-header>
    <set-header name="ErrorMessage" exists-action="override">
      <value>@(context.LastError.Message)</value>
    </set-header>
  </on-error>
</policies>
XML
}