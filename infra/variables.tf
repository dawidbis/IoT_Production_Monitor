variable "project" {
  type        = string
  description = "Short project code used as a prefix for resource names."
  default     = "factorytel"

  validation {
    condition     = can(regex("^[a-z0-9]{3,12}$", var.project))
    error_message = "Project must be 3-12 lowercase alphanumeric characters."
  }
}

variable "environment" {
  type        = string
  description = "Deployment environment (dev, test, prod)."
  default     = "dev"

  validation {
    condition     = contains(["dev", "test", "prod"], var.environment)
    error_message = "Environment must be one of: dev, test, prod."
  }
}

variable "location" {
  type        = string
  description = "Azure region for all resources."
  default     = "westeurope"
}

variable "app_service_sku" {
  type        = string
  description = "SKU for the Linux App Service Plan."
  default     = "B1"
}

variable "sql_admin_login" {
  type        = string
  description = "Administrator login for Azure SQL Server."
  default     = "sqladmin"
}

variable "sql_admin_password" {
  type        = string
  description = "Administrator password for Azure SQL Server. Supplied as a secret variable from the pipeline."
  sensitive   = true
}

variable "iothub_sku" {
  type        = string
  description = "Azure IoT Hub SKU name."
  default     = "B1"
}

variable "iothub_capacity" {
  type        = number
  description = "Number of provisioned IoT Hub units."
  default     = 1
}

variable "iothub_location" {
  type        = string
  description = "Region for the IoT Hub. Leave empty to use var.location; set explicitly when the main region lacks IoT Hub (e.g. polandcentral -> germanywestcentral)."
  default     = ""
}

variable "tags" {
  type        = map(string)
  description = "Tags applied to every resource."
  default = {
    project   = "Factory Telemetry & OEE Monitor"
    managedBy = "Terraform"
    owner     = "DevOps"
  }
}
