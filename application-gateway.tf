# Public IP for Application Gateway
resource "azurerm_public_ip" "appgw" {
  name                = "pip-${local.appgw_name}"
  location            = azurerm_resource_group.this.location
  resource_group_name = azurerm_resource_group.this.name
  allocation_method   = "Static"
  sku                 = "Standard"
  domain_name_label   = "apim-${var.organization}-${var.environment}-${random_string.suffix.result}"
  tags                = local.common_tags
}

# User Assigned Identity for Application Gateway
resource "azurerm_user_assigned_identity" "appgw" {
  name                = "id-${local.appgw_name}"
  location            = azurerm_resource_group.this.location
  resource_group_name = azurerm_resource_group.this.name
  tags                = local.common_tags
}

# Key Vault Access Policy for Application Gateway
resource "azurerm_key_vault_access_policy" "appgw" {
  key_vault_id = azurerm_key_vault.this.id
  tenant_id    = azurerm_user_assigned_identity.appgw.tenant_id
  object_id    = azurerm_user_assigned_identity.appgw.principal_id

  secret_permissions = [
    "Get"
  ]

  certificate_permissions = [
    "Get"
  ]
}

# Web Application Firewall Policy
resource "azurerm_web_application_firewall_policy" "this" {
  name                = "waf-policy-${local.resource_suffix}"
  resource_group_name = azurerm_resource_group.this.name
  location            = azurerm_resource_group.this.location

  policy_settings {
    enabled                     = true
    mode                        = "Prevention"
    request_body_check          = true
    file_upload_limit_in_mb     = 100
    max_request_body_size_in_kb = 128
  }

  managed_rules {
    managed_rule_set {
      type    = "OWASP"
      version = "3.2"
    }

    managed_rule_set {
      type    = "Microsoft_BotManagerRuleSet"
      version = "0.1"
    }
  }

  # Custom rules for API protection
  custom_rules {
    name      = "RateLimitRule"
    priority  = 1
    rule_type = "RateLimitRule"
    action    = "Block"

    match_conditions {
      match_variables {
        variable_name = "RemoteAddr"
      }
      operator           = "IPMatch"
      negation_condition = false
      match_values       = ["0.0.0.0/0"]
    }

    rate_limit_duration  = "FiveMins"
    rate_limit_threshold = 100
  }

  tags = local.common_tags
}

# Application Gateway
resource "azurerm_application_gateway" "this" {
  name                = local.appgw_name
  resource_group_name = azurerm_resource_group.this.name
  location            = azurerm_resource_group.this.location

  sku {
    name     = var.appgw_sku.name
    tier     = var.appgw_sku.tier
    capacity = var.appgw_sku.capacity
  }

  # Managed Identity
  identity {
    type         = "UserAssigned"
    identity_ids = [azurerm_user_assigned_identity.appgw.id]
  }

  # Gateway IP Configuration
  gateway_ip_configuration {
    name      = "appgw-ip-configuration"
    subnet_id = azurerm_subnet.appgw.id
  }

  # Frontend Port Configuration
  frontend_port {
    name = "port_80"
    port = 80
  }

  frontend_port {
    name = "port_443"
    port = 443
  }

  # Frontend IP Configuration
  frontend_ip_configuration {
    name                 = "appgw-public-frontend-ip"
    public_ip_address_id = azurerm_public_ip.appgw.id
  }

  # Backend Address Pool
  backend_address_pool {
    name  = "apim-backend-pool"
    fqdns = [azurerm_api_management.this.gateway_url]
  }

  # Backend HTTP Settings
  backend_http_settings {
    name                  = "apim-backend-http-settings"
    cookie_based_affinity = "Disabled"
    path                  = "/"
    port                  = 80
    protocol              = "Http"
    request_timeout       = 60
    probe_name            = "apim-health-probe"

    # Custom host header for API Management
    host_name = azurerm_api_management.this.gateway_url
  }

  backend_http_settings {
    name                  = "apim-backend-https-settings"
    cookie_based_affinity = "Disabled"
    path                  = "/"
    port                  = 443
    protocol              = "Https"
    request_timeout       = 60
    probe_name            = "apim-health-probe-https"

    # Custom host header for API Management
    host_name = azurerm_api_management.this.gateway_url
  }

  # Health Probes
  probe {
    name                = "apim-health-probe"
    protocol            = "Http"
    path                = "/status-0123456789abcdef"
    host                = azurerm_api_management.this.gateway_url
    interval            = 30
    timeout             = 30
    unhealthy_threshold = 3

    match {
      status_code = ["200-399"]
    }
  }

  probe {
    name                = "apim-health-probe-https"
    protocol            = "Https"
    path                = "/status-0123456789abcdef"
    host                = azurerm_api_management.this.gateway_url
    interval            = 30
    timeout             = 30
    unhealthy_threshold = 3

    match {
      status_code = ["200-399"]
    }
  }

  # SSL Certificate from Key Vault
  ssl_certificate {
    name                = "api-ssl-certificate"
    key_vault_secret_id = azurerm_key_vault_certificate.api_ssl.secret_id
  }

  # HTTP Listener
  http_listener {
    name                           = "appgw-http-listener"
    frontend_ip_configuration_name = "appgw-public-frontend-ip"
    frontend_port_name             = "port_80"
    protocol                       = "Http"
  }

  # HTTPS Listener
  http_listener {
    name                           = "appgw-https-listener"
    frontend_ip_configuration_name = "appgw-public-frontend-ip"
    frontend_port_name             = "port_443"
    protocol                       = "Https"
    ssl_certificate_name           = "api-ssl-certificate"
  }

  # Request Routing Rule - HTTP to HTTPS redirect
  request_routing_rule {
    name               = "http-to-https-redirect"
    rule_type          = "Basic"
    http_listener_name = "appgw-http-listener"
    priority           = 100

    redirect_configuration_name = "http-to-https-redirect-config"
  }

  # Request Routing Rule - HTTPS
  request_routing_rule {
    name                       = "appgw-https-routing-rule"
    rule_type                  = "Basic"
    http_listener_name         = "appgw-https-listener"
    backend_address_pool_name  = "apim-backend-pool"
    backend_http_settings_name = "apim-backend-https-settings"
    priority                   = 200
  }

  # Redirect Configuration
  redirect_configuration {
    name                 = "http-to-https-redirect-config"
    redirect_type        = "Permanent"
    target_listener_name = "appgw-https-listener"
    include_path         = true
    include_query_string = true
  }

  # WAF Configuration
  firewall_policy_id = azurerm_web_application_firewall_policy.this.id

  # Enable HTTP/2
  enable_http2 = true

  tags = local.common_tags

  depends_on = [
    azurerm_api_management.this,
    azurerm_key_vault_access_policy.appgw
  ]
}