# General variables
variable "location" {
  type        = string
  description = "The Azure region where resources will be deployed"
  default     = "East US"
}

variable "environment" {
  type        = string
  description = "Environment name (dev, staging, prod)"
  default     = "dev"
}

variable "organization" {
  type        = string
  description = "Organization or project name"
  default     = "contoso"
}

# Network variables
variable "vnet_address_space" {
  type        = list(string)
  description = "Address space for the virtual network"
  default     = ["10.0.0.0/16"]
}

variable "apim_subnet_address_prefix" {
  type        = string
  description = "Address prefix for API Management subnet"
  default     = "10.0.1.0/24"
}

variable "appgw_subnet_address_prefix" {
  type        = string
  description = "Address prefix for Application Gateway subnet"
  default     = "10.0.2.0/24"
}

variable "backend_subnet_address_prefix" {
  type        = string
  description = "Address prefix for backend services subnet"
  default     = "10.0.3.0/24"
}

# API Management variables
variable "apim_sku_name" {
  type        = string
  description = "SKU name for API Management instance"
  default     = "Developer_1"
  validation {
    condition     = contains(["Developer_1", "Standard_1", "Premium_1"], var.apim_sku_name)
    error_message = "API Management SKU must be Developer_1, Standard_1, or Premium_1."
  }
}

variable "apim_publisher_name" {
  type        = string
  description = "Publisher name for API Management"
  default     = "Contoso API Team"
}

variable "apim_publisher_email" {
  type        = string
  description = "Publisher email for API Management"
  default     = "admin@contoso.com"
}

# Application Gateway variables
variable "appgw_sku" {
  type = object({
    name     = string
    tier     = string
    capacity = number
  })
  description = "Application Gateway SKU configuration"
  default = {
    name     = "WAF_v2"
    tier     = "WAF_v2"
    capacity = 2
  }
}

# Tags
variable "tags" {
  type        = map(string)
  description = "Common tags applied to all resources"
  default = {
    Environment = "dev"
    Owner       = "Platform Team"
    Project     = "API Management Landing Zone"
  }
}