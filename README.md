# Azure API Management Landing Zone

This Terraform configuration creates a complete Azure API Management landing zone based on the [Microsoft Cloud Adoption Framework](https://learn.microsoft.com/en-us/azure/cloud-adoption-framework/scenarios/app-platform/api-management/landing-zone-accelerator).

## Architecture Overview

The solution deploys API Management in internal VNET mode with Application Gateway providing external access and Web Application Firewall (WAF) protection. This architecture ensures secure, scalable, and monitored API operations.

### Key Components

- **API Management**: Deployed in internal VNET mode for security
- **Application Gateway**: Frontend load balancer with WAF protection
- **Azure Key Vault**: Secure secrets and certificate management
- **Virtual Network**: Segmented subnets with network security groups
- **Backend Services**: Sample App Service and AKS for API backends
- **Monitoring**: Azure Monitor, Log Analytics, and Application Insights

## Prerequisites

- Azure subscription with appropriate permissions
- Terraform >= 1.0 installed
- Azure CLI installed and authenticated
- (Optional) kubectl for AKS management

## Deployment

### 1. Clone and Initialize

```bash
git clone <repository-url>
cd api-management-landing-zone
terraform init
```

### 2. Configure Variables

Copy and customize the variables:

```bash
cp terraform.tfvars.example terraform.tfvars
```

Edit `terraform.tfvars` with your specific values:

```hcl
location         = "East US"
environment      = "dev"
organization     = "contoso"
apim_sku_name    = "Developer_1"
apim_publisher_name  = "Your API Team"
apim_publisher_email = "api-team@yourcompany.com"

tags = {
  Environment = "Development"
  Owner       = "Platform Team"
  Project     = "API Management Landing Zone"
}
```

### 3. Plan and Apply

```bash
# Review the deployment plan
terraform plan

# Deploy the infrastructure
terraform apply
```

The deployment typically takes 45-60 minutes due to API Management provisioning time.

### 4. Post-Deployment Configuration

After successful deployment, complete these steps:

1. **Configure DNS**: Update your DNS to point to the Application Gateway public IP
2. **Import APIs**: Use the developer portal or Azure CLI to import your APIs
3. **Set up Authentication**: Configure Azure AD for developer portal access
4. **Review Monitoring**: Check alerts and dashboards in Azure Monitor

## Configuration Options

### Network Configuration

```hcl
vnet_address_space             = ["10.0.0.0/16"]
apim_subnet_address_prefix     = "10.0.1.0/24"
appgw_subnet_address_prefix    = "10.0.2.0/24"
backend_subnet_address_prefix  = "10.0.3.0/24"
```

### API Management SKU Options

- `Developer_1`: Development and testing (no SLA)
- `Standard_1`: Production workloads with SLA
- `Premium_1`: Enterprise features with multi-region support

### Application Gateway SKU

```hcl
appgw_sku = {
  name     = "WAF_v2"
  tier     = "WAF_v2"
  capacity = 2
}
```

## Security Features

### Network Security

- **Internal VNET**: API Management deployed in internal mode
- **Network Security Groups**: Granular traffic control
- **Private Endpoints**: Secure access to Key Vault and other services
- **WAF Protection**: OWASP rule sets and custom rules

### Identity and Access

- **Managed Identities**: Service-to-service authentication
- **Key Vault Integration**: Secure certificate and secrets management
- **RBAC**: Role-based access control for all resources

### Monitoring and Compliance

- **Diagnostic Logging**: Comprehensive audit trails
- **Security Alerts**: Automated threat detection
- **Policy Enforcement**: Azure Policy compliance monitoring

## Backend Integration

### App Service

The solution includes a sample App Service configured with:
- VNET integration for secure communication
- Private endpoint for internal access
- Managed identity for authentication

### Azure Kubernetes Service (AKS)

Sample AKS cluster with:
- Private cluster configuration
- Azure CNI networking
- Azure AD integration
- Monitoring enabled

### Adding Custom Backends

```hcl
resource "azurerm_api_management_backend" "custom" {
  name                = "custom-backend"
  resource_group_name = azurerm_resource_group.this.name
  api_management_name = azurerm_api_management.this.name
  protocol            = "http"
  url                 = "https://your-backend-service.com"
}
```

## Monitoring and Alerts

The solution includes pre-configured monitoring:

### Metrics and Logs

- API Management gateway logs
- Application Gateway access logs
- WAF logs and blocked requests
- Key Vault audit events

### Alerts

- API Management availability
- Application Gateway unhealthy hosts
- Key Vault policy violations
- Custom metric alerts

### Log Analytics Queries

Pre-built queries for common scenarios:
- API error analysis
- WAF blocked requests
- Performance metrics
- Security audit trails

## Cost Optimization

### Development Environment

- Use `Developer_1` SKU for API Management
- Reduce Application Gateway capacity
- Set Log Analytics daily quota

### Production Environment

- Use `Standard_1` or `Premium_1` SKU
- Enable autoscaling for Application Gateway
- Configure retention policies

## Troubleshooting

### Common Issues

1. **Long Deployment Time**: API Management can take 45+ minutes to provision
2. **Certificate Errors**: Ensure Key Vault access policies are correct
3. **Network Connectivity**: Verify NSG rules and subnet configurations
4. **DNS Resolution**: Check private DNS zones and virtual network links

### Diagnostic Commands

```bash
# Check API Management status
az apim show --name <apim-name> --resource-group <rg-name> --query "provisioningState"

# Test Application Gateway health
az network application-gateway show-health --name <appgw-name> --resource-group <rg-name>

# View Key Vault access policies
az keyvault show --name <kv-name> --resource-group <rg-name> --query "properties.accessPolicies"
```

## Customization

### Adding New APIs

1. Use the developer portal UI
2. Azure CLI: `az apim api import`
3. Terraform resources for infrastructure-as-code

### Custom Policies

Create API-level or global policies for:
- Authentication and authorization
- Rate limiting and quotas
- Request/response transformation
- Backend routing and load balancing

### Additional Backend Services

The modular design supports adding:
- Azure Functions
- Logic Apps
- External APIs
- On-premises services (via VPN/ExpressRoute)

## Security Baseline Compliance

This solution implements security controls from:
- Azure API Management Security Baseline
- Azure Application Gateway Security Baseline
- Azure Key Vault Security Baseline
- Azure Monitor Security Baseline

## Support

For issues and questions:
1. Check the troubleshooting section above
2. Review Azure documentation for specific services
3. Open an issue in the repository
4. Contact your platform team

## License

This project is licensed under the MIT License - see the LICENSE file for details.
