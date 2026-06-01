output "resource_group_name" {
  description = "Name of the resource group holding all resources."
  value       = azurerm_resource_group.main.name
}

output "app_service_name" {
  description = "Name of the App Service hosting the API (used by the deploy stage)."
  value       = azurerm_linux_web_app.api.name
}

output "app_service_url" {
  description = "Public HTTPS URL of the API."
  value       = "https://${azurerm_linux_web_app.api.default_hostname}"
}

output "container_registry_login_server" {
  description = "ACR login server the pipeline pushes the image to."
  value       = azurerm_container_registry.main.login_server
}

output "sql_server_fqdn" {
  description = "Fully-qualified domain name of the Azure SQL Server."
  value       = azurerm_mssql_server.main.fully_qualified_domain_name
}

output "iothub_hostname" {
  description = "Hostname of the IoT Hub gateway."
  value       = azurerm_iothub.main.hostname
}
