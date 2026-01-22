# Log Analytics Workspace
resource "azurerm_log_analytics_workspace" "this" {
  name                = local.log_analytics_name
  location            = azurerm_resource_group.this.location
  resource_group_name = azurerm_resource_group.this.name
  sku                 = "PerGB2018"
  retention_in_days   = 30

  # Enable daily cap to control costs
  daily_quota_gb = 10

  tags = local.common_tags
}

# Application Insights
resource "azurerm_application_insights" "this" {
  name                = local.app_insights_name
  location            = azurerm_resource_group.this.location
  resource_group_name = azurerm_resource_group.this.name
  workspace_id        = azurerm_log_analytics_workspace.this.id
  application_type    = "web"

  tags = local.common_tags
}

# Diagnostic Settings for API Management
resource "azurerm_monitor_diagnostic_setting" "apim" {
  name                       = "diag-${azurerm_api_management.this.name}"
  target_resource_id         = azurerm_api_management.this.id
  log_analytics_workspace_id = azurerm_log_analytics_workspace.this.id

  enabled_log {
    category = "GatewayLogs"
  }

  enabled_log {
    category = "WebSocketConnectionLogs"
  }

  enabled_metric {
    category = "AllMetrics"
  }
}

# Diagnostic Settings for Application Gateway
resource "azurerm_monitor_diagnostic_setting" "appgw" {
  name                       = "diag-${azurerm_application_gateway.this.name}"
  target_resource_id         = azurerm_application_gateway.this.id
  log_analytics_workspace_id = azurerm_log_analytics_workspace.this.id

  enabled_log {
    category = "ApplicationGatewayAccessLog"
  }

  enabled_log {
    category = "ApplicationGatewayPerformanceLog"
  }

  enabled_log {
    category = "ApplicationGatewayFirewallLog"
  }

  enabled_metric {
    category = "AllMetrics"
  }
}

# Diagnostic Settings for Key Vault
resource "azurerm_monitor_diagnostic_setting" "key_vault" {
  name                       = "diag-${azurerm_key_vault.this.name}"
  target_resource_id         = azurerm_key_vault.this.id
  log_analytics_workspace_id = azurerm_log_analytics_workspace.this.id

  enabled_log {
    category = "AuditEvent"
  }

  enabled_log {
    category = "AzurePolicyEvaluationDetails"
  }

  enabled_metric {
    category = "AllMetrics"
  }
}

# Action Group for alerts
resource "azurerm_monitor_action_group" "main" {
  name                = "ag-apim-alerts-${local.resource_suffix}"
  resource_group_name = azurerm_resource_group.this.name
  short_name          = "apim-alerts"

  email_receiver {
    name                    = "admin-email"
    email_address           = var.apim_publisher_email
    use_common_alert_schema = true
  }

  tags = local.common_tags
}

# API Management Availability Alert
resource "azurerm_monitor_metric_alert" "apim_availability" {
  name                = "alert-apim-availability-${local.resource_suffix}"
  resource_group_name = azurerm_resource_group.this.name
  scopes              = [azurerm_api_management.this.id]
  description         = "API Management gateway availability is below threshold"
  severity            = 1

  criteria {
    metric_namespace = "Microsoft.ApiManagement/service"
    metric_name      = "Requests"
    aggregation      = "Total"
    operator         = "LessThan"
    threshold        = 1

    dimension {
      name     = "GatewayResponseCodeCategory"
      operator = "Include"
      values   = ["2XX", "3XX"]
    }
  }

  frequency   = "PT5M"
  window_size = "PT5M"

  action {
    action_group_id = azurerm_monitor_action_group.main.id
  }

  tags = local.common_tags
}

# Application Gateway Unhealthy Host Count Alert
resource "azurerm_monitor_metric_alert" "appgw_unhealthy_hosts" {
  name                = "alert-appgw-unhealthy-hosts-${local.resource_suffix}"
  resource_group_name = azurerm_resource_group.this.name
  scopes              = [azurerm_application_gateway.this.id]
  description         = "Application Gateway has unhealthy backend hosts"
  severity            = 2

  criteria {
    metric_namespace = "Microsoft.Network/applicationGateways"
    metric_name      = "UnhealthyHostCount"
    aggregation      = "Maximum"
    operator         = "GreaterThan"
    threshold        = 0
  }

  frequency   = "PT1M"
  window_size = "PT5M"

  action {
    action_group_id = azurerm_monitor_action_group.main.id
  }

  tags = local.common_tags
}

# Key Vault Access Policy Violations Alert
resource "azurerm_monitor_metric_alert" "key_vault_policy_violations" {
  name                = "alert-kv-policy-violations-${local.resource_suffix}"
  resource_group_name = azurerm_resource_group.this.name
  scopes              = [azurerm_key_vault.this.id]
  description         = "Key Vault policy violations detected"
  severity            = 1

  criteria {
    metric_namespace = "Microsoft.KeyVault/vaults"
    metric_name      = "ServiceApiHit"
    aggregation      = "Count"
    operator         = "GreaterThan"
    threshold        = 10

    dimension {
      name     = "StatusCodeClass"
      operator = "Include"
      values   = ["4xx"]
    }
  }

  frequency   = "PT5M"
  window_size = "PT15M"

  action {
    action_group_id = azurerm_monitor_action_group.main.id
  }

  tags = local.common_tags
}

# Log Analytics Saved Queries
resource "azurerm_log_analytics_saved_search" "api_errors" {
  name                       = "API Management Errors"
  log_analytics_workspace_id = azurerm_log_analytics_workspace.this.id

  category     = "API Management"
  display_name = "API Management Error Analysis"
  query        = <<QUERY
ApiManagementGatewayLogs
| where TimeGenerated > ago(24h)
| where ResponseCode >= 400
| summarize ErrorCount = count() by ResponseCode, Method, Url, bin(TimeGenerated, 1h)
| order by TimeGenerated desc, ErrorCount desc
QUERY
}

resource "azurerm_log_analytics_saved_search" "waf_blocks" {
  name                       = "WAF Blocked Requests"
  log_analytics_workspace_id = azurerm_log_analytics_workspace.this.id

  category     = "Security"
  display_name = "WAF Blocked Requests Analysis"
  query        = <<QUERY
AzureDiagnostics
| where ResourceProvider == "MICROSOFT.NETWORK" and Category == "ApplicationGatewayFirewallLog"
| where action_s == "Blocked"
| summarize BlockedCount = count() by clientIP_s, ruleId_s, bin(TimeGenerated, 1h)
| order by TimeGenerated desc, BlockedCount desc
QUERY
}