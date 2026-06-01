# Runbook — Operations

Day-to-day operational procedures for the Factory Telemetry & OEE Monitor.

## Run the API locally

```powershell
dotnet run --project src/FactoryTelemetry.Api
# API on http://localhost:5000 (and https://localhost:5001)
# Swagger UI at http://localhost:5000/swagger
```

No database required — the in-memory provider is used automatically when no
`ConnectionStrings:TelemetryDb` is configured.

## Generate sample data & view OEE

```powershell
# In a second terminal, stream telemetry for two machines
./scripts/New-SampleTelemetry.ps1 -BaseUrl http://localhost:5000 -Count 30 -DelayMs 100

# Then print the OEE report
./scripts/Get-OeeReport.ps1 -BaseUrl http://localhost:5000
```

## Run all tests & quality gates

```powershell
dotnet test                                  # .NET unit + integration tests
./scripts/Invoke-StaticAnalysis.ps1          # PSScriptAnalyzer + Pester
```

## Provision / update cloud infrastructure

See [`infra/README.md`](../infra/README.md). In short:

```powershell
az login
cd infra
terraform init -backend-config=...           # see infra/README.md
terraform plan  -var="sql_admin_password=$env:SQL_ADMIN_PASSWORD"
terraform apply
```

## Deploy

Deployment is automated by [`pipelines/azure-pipelines.yml`](../pipelines/azure-pipelines.yml)
on merge to `main`. To deploy manually:

```powershell
# Build & push image
docker build -t $acr.azurecr.io/factorytelemetry:local src/FactoryTelemetry.Api
docker push $acr.azurecr.io/factorytelemetry:local

# Point the Web App at the new tag
az webapp config container set --name <app> --resource-group <rg> `
  --container-image-name $acr.azurecr.io/factorytelemetry:local
```

## Health & troubleshooting

| Symptom | Check |
| --- | --- |
| API returns 5xx | App Service **Log stream**; Application Insights failures blade |
| `/health` not green | Container started? `WEBSITES_PORT=8080`? image tag exists in ACR? |
| DB errors | SQL firewall rule `AllowAzureServices`; connection string in App Service config |
| Image won't pull | Web App managed identity has `AcrPull` on the registry |

## Endpoints reference

| Method | Route | Purpose |
| --- | --- | --- |
| GET | `/health` | Liveness probe |
| POST | `/api/telemetry` | Ingest one telemetry sample |
| GET | `/api/telemetry/{machineId}?take=50` | Recent readings |
| GET | `/api/machines/{machineId}/oee?fromUtc=&toUtc=` | Compute OEE |
| GET | `/swagger` | Interactive API docs |
