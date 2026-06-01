# Infrastructure (Terraform)

Infrastructure-as-Code for the **Factory Telemetry & OEE Monitor**, targeting Microsoft Azure
via the `hashicorp/azurerm` provider.

## What gets provisioned

| Resource | Azure type | Purpose |
| --- | --- | --- |
| Resource Group | `azurerm_resource_group` | Logical container for everything |
| Container Registry | `azurerm_container_registry` | Stores the API container image |
| App Service Plan + Web App | `azurerm_service_plan`, `azurerm_linux_web_app` | Hosts the containerised API (Linux/PaaS) |
| Azure SQL Server + Database | `azurerm_mssql_server`, `azurerm_mssql_database` | Persists telemetry |
| IoT Hub | `azurerm_iothub` | Cloud gateway for shop-floor signals |
| Log Analytics + App Insights | `azurerm_log_analytics_workspace`, `azurerm_application_insights` | Observability |

The Web App uses a **system-assigned managed identity** with an `AcrPull` role assignment —
no registry admin credentials are stored anywhere.

## Prerequisites

- [Terraform](https://developer.hashicorp.com/terraform/install) >= 1.7
- [Azure CLI](https://learn.microsoft.com/cli/azure/install-azure-cli), authenticated: `az login`
- A storage account + container for remote state (referenced by the backend)

## Usage (local)

```powershell
# 1. Authenticate
az login
az account set --subscription "<your-subscription-id>"

# 2. Initialise with a remote backend
terraform init `
  -backend-config="resource_group_name=rg-tfstate" `
  -backend-config="storage_account_name=sttfstate<unique>" `
  -backend-config="container_name=tfstate" `
  -backend-config="key=factory-telemetry-dev.tfstate"

# 3. Plan (password passed as a secret, never committed)
terraform plan -var="sql_admin_password=$env:SQL_ADMIN_PASSWORD" -out tfplan

# 4. Apply
terraform apply tfplan
```

## Conventions

- **Naming:** `<type>-<project>-<environment>-<suffix>` (a random suffix makes globally
  unique names — SQL Server, IoT Hub, ACR — collision-free).
- **No secrets in source:** `terraform.tfvars` is git-ignored; the SQL password is supplied
  as a pipeline secret / environment variable.
- **State:** stored remotely in Azure Storage (`backend "azurerm"`).

## Validation

```powershell
terraform fmt -check -recursive
terraform validate
```

Both run automatically in the CI stage (see `../pipelines/azure-pipelines.yml`).
