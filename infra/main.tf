locals {
  # Globally-unique, predictable naming: <project>-<env>-<resource>-<suffix>
  name_prefix = "${var.project}-${var.environment}"
  suffix      = random_string.suffix.result
  tags        = merge(var.tags, { environment = var.environment })
}

# Random suffix guarantees global uniqueness for SQL Server / IoT Hub / ACR names.
resource "random_string" "suffix" {
  length  = 5
  special = false
  upper   = false
}

resource "azurerm_resource_group" "main" {
  name     = "rg-${local.name_prefix}"
  location = var.location
  tags     = local.tags
}

# ---- Observability ------------------------------------------------------------
resource "azurerm_log_analytics_workspace" "main" {
  name                = "log-${local.name_prefix}"
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name
  sku                 = "PerGB2018"
  retention_in_days   = 30
  tags                = local.tags
}

resource "azurerm_application_insights" "main" {
  name                = "appi-${local.name_prefix}"
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name
  workspace_id        = azurerm_log_analytics_workspace.main.id
  application_type    = "web"
  tags                = local.tags
}

# ---- Container registry (holds the API image) ---------------------------------
resource "azurerm_container_registry" "main" {
  name                = "acr${var.project}${var.environment}${local.suffix}"
  resource_group_name = azurerm_resource_group.main.name
  location            = azurerm_resource_group.main.location
  sku                 = "Basic"
  admin_enabled       = false
  tags                = local.tags
}

# ---- Compute: Linux App Service running the container --------------------------
resource "azurerm_service_plan" "main" {
  name                = "plan-${local.name_prefix}"
  resource_group_name = azurerm_resource_group.main.name
  location            = azurerm_resource_group.main.location
  os_type             = "Linux"
  sku_name            = var.app_service_sku
  tags                = local.tags
}

resource "azurerm_linux_web_app" "api" {
  name                = "app-${local.name_prefix}-${local.suffix}"
  resource_group_name = azurerm_resource_group.main.name
  location            = azurerm_service_plan.main.location
  service_plan_id     = azurerm_service_plan.main.id
  https_only          = true
  tags                = local.tags

  # System-assigned identity is used to pull the image from ACR (no admin creds).
  identity {
    type = "SystemAssigned"
  }

  site_config {
    container_registry_use_managed_identity = true
    ftps_state                              = "Disabled"
    minimum_tls_version                     = "1.2"
    health_check_path                       = "/health"

    application_stack {
      docker_image_name   = "factorytelemetry:latest"
      docker_registry_url = "https://${azurerm_container_registry.main.login_server}"
    }
  }

  app_settings = {
    "WEBSITES_PORT"                         = "8080"
    "ASPNETCORE_ENVIRONMENT"                = var.environment == "prod" ? "Production" : "Staging"
    "APPLICATIONINSIGHTS_CONNECTION_STRING" = azurerm_application_insights.main.connection_string
    "IOTHUB_HOSTNAME"                       = azurerm_iothub.main.hostname
  }

  # App Service exposes this as ConnectionStrings:TelemetryDb to the .NET app.
  connection_string {
    name  = "TelemetryDb"
    type  = "SQLAzure"
    value = "Server=tcp:${azurerm_mssql_server.main.fully_qualified_domain_name},1433;Database=${azurerm_mssql_database.main.name};User ID=${var.sql_admin_login};Password=${var.sql_admin_password};Encrypt=true;TrustServerCertificate=false;Connection Timeout=30;"
  }
}

# Allow the web app's managed identity to pull images from the registry.
resource "azurerm_role_assignment" "acr_pull" {
  scope                = azurerm_container_registry.main.id
  role_definition_name = "AcrPull"
  principal_id         = azurerm_linux_web_app.api.identity[0].principal_id
}

# ---- Data: Azure SQL ----------------------------------------------------------
resource "azurerm_mssql_server" "main" {
  name                         = "sql-${local.name_prefix}-${local.suffix}"
  resource_group_name          = azurerm_resource_group.main.name
  location                     = azurerm_resource_group.main.location
  version                      = "12.0"
  administrator_login          = var.sql_admin_login
  administrator_login_password = var.sql_admin_password
  minimum_tls_version          = "1.2"
  tags                         = local.tags
}

resource "azurerm_mssql_database" "main" {
  name        = "sqldb-telemetry"
  server_id   = azurerm_mssql_server.main.id
  sku_name    = "Basic"
  max_size_gb = 2
  collation   = "SQL_Latin1_General_CP1_CI_AS"
  tags        = local.tags
}

# Permit other Azure services (incl. the App Service) to reach the SQL Server.
resource "azurerm_mssql_firewall_rule" "allow_azure" {
  name             = "AllowAzureServices"
  server_id        = azurerm_mssql_server.main.id
  start_ip_address = "0.0.0.0"
  end_ip_address   = "0.0.0.0"
}

# ---- Cloud gateway: IoT Hub ---------------------------------------------------
resource "azurerm_iothub" "main" {
  name                = "iot-${local.name_prefix}-${local.suffix}"
  resource_group_name = azurerm_resource_group.main.name
  location            = azurerm_resource_group.main.location
  tags                = local.tags

  sku {
    name     = var.iothub_sku
    capacity = var.iothub_capacity
  }
}
