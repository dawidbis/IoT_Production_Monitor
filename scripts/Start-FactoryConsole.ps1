<#
.SYNOPSIS
    Interactive operator console for the Factory Telemetry & OEE Monitor.
.DESCRIPTION
    One entry point (wrapped by FactoryTelemetry.bat) to drive the running API (local or Azure).
    Lets the developer check health, stream simulated telemetry, pull OEE reports, watch a live
    monitor, browse recent readings, open Swagger, switch environment, and run the quality gate.
    It also exposes an Azure infrastructure lifecycle menu (provision via Terraform, deploy the
    app, start/stop the Web App, and destroy everything to stop consuming credits).
    Cross-platform (Windows PowerShell 5.1 and PowerShell 7+).
    Target defaults to the Azure URL from FactoryTelemetry.config.psd1.
.EXAMPLE
    ./Start-FactoryConsole.ps1
.EXAMPLE
    ./Start-FactoryConsole.ps1 -Target Local
#>
[CmdletBinding()]
param(
    [string]$BaseUrl,

    [ValidateSet('Azure', 'Local')]
    [string]$Target
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

Import-Module "$PSScriptRoot/FactoryTelemetry.Tools.psm1" -Force
$script:Cfg = Get-FactoryConfig
$script:Machines = $script:Cfg.Machines

if ($BaseUrl) {
    $script:BaseUrl = $BaseUrl
    $script:TargetName = 'Custom'
}
else {
    $chosen = if ($Target) { $Target } else { [string]$script:Cfg.DefaultTarget }
    $script:TargetName = $chosen
    $script:BaseUrl = if ($chosen -eq 'Local') { $script:Cfg.LocalBaseUrl } else { $script:Cfg.AzureBaseUrl }
}

function Show-Header {
    Clear-Host
    Write-Host '================================================================' -ForegroundColor DarkCyan
    Write-Host '   Factory Telemetry & OEE Monitor  -  konsola operatora' -ForegroundColor Cyan
    Write-Host '================================================================' -ForegroundColor DarkCyan
    $health = Test-FactoryHealth -BaseUrl $script:BaseUrl -TimeoutSec 4
    Write-Host ("  Srodowisko : {0}" -f $script:TargetName)
    Write-Host ("  Adres      : {0}" -f $script:BaseUrl)
    Write-Host -NoNewline '  Status API : '
    if ($health.Healthy) { Write-Host 'ONLINE' -ForegroundColor Green }
    else { Write-Host 'OFFLINE' -ForegroundColor Red }
    Write-Host ("  Maszyny    : {0}" -f ($script:Machines -join ', '))
    Write-Host '----------------------------------------------------------------' -ForegroundColor DarkGray
}

function Show-Menu {
    Write-Host '  [1] Sprawdz stan API (health)'
    Write-Host '  [2] Wyslij telemetrie (symulator hali)'
    Write-Host '  [3] Raport OEE'
    Write-Host '  [4] Monitor na zywo (auto-odswiezanie)'
    Write-Host '  [5] Ostatnie odczyty maszyny'
    Write-Host '  [6] Otworz Swagger w przegladarce'
    Write-Host '  [7] Zmien srodowisko (Azure / Local / wlasny URL)'
    Write-Host '  [8] Bramka jakosci (PSScriptAnalyzer + Pester)'
    Write-Host '  [9] Zarzadzanie Azure (provision / start / stop / usun)' -ForegroundColor Cyan
    Write-Host '  [0] Wyjscie'
    Write-Host ''
}

function Read-IntOr {
    param([string]$Prompt, [int]$Default)
    $raw = Read-Host ("{0} [{1}]" -f $Prompt, $Default)
    if ([string]::IsNullOrWhiteSpace($raw)) { return $Default }
    $parsed = 0
    if ([int]::TryParse($raw, [ref]$parsed)) { return $parsed }
    return $Default
}

function Invoke-HealthCheck {
    $health = Test-FactoryHealth -BaseUrl $script:BaseUrl
    if ($health.Healthy) {
        Write-Host ("  API zdrowe. Czas serwera (UTC): {0}" -f $health.Utc) -ForegroundColor Green
    }
    else {
        Write-Host ("  API niedostepne: {0}" -f $health.Status) -ForegroundColor Red
    }
}

function Invoke-Simulator {
    $count = Read-IntOr -Prompt '  Ile probek na maszyne?' -Default 30
    $delay = Read-IntOr -Prompt '  Odstep miedzy cyklami (ms)?' -Default 150
    & "$PSScriptRoot/New-SampleTelemetry.ps1" -BaseUrl $script:BaseUrl -Machines $script:Machines -Count $count -DelayMs $delay
}

function Invoke-Report {
    foreach ($machine in $script:Machines) {
        try {
            Get-MachineOee -BaseUrl $script:BaseUrl -MachineId $machine | Format-OeeReport
        }
        catch {
            Write-Host ("  Brak danych OEE dla {0} ({1})" -f $machine, $_.Exception.Message) -ForegroundColor Yellow
        }
        Write-Host ''
    }
}

function Invoke-Monitor {
    $interval = Read-IntOr -Prompt '  Co ile sekund odswiezac?' -Default 5
    Write-Host '  Uruchamiam monitor... (dowolny klawisz = powrot do menu)' -ForegroundColor DarkGray
    Start-Sleep -Milliseconds 700
    while (-not [Console]::KeyAvailable) {
        Show-Header
        Write-Host '  MONITOR NA ZYWO   (dowolny klawisz = stop)' -ForegroundColor Cyan
        Write-Host ''
        foreach ($machine in $script:Machines) {
            try {
                $oee = Get-MachineOee -BaseUrl $script:BaseUrl -MachineId $machine
                Write-Host ('  ' + ($oee | Format-OeeLine))
            }
            catch {
                Write-Host ("  {0,-14} brak danych" -f $machine) -ForegroundColor DarkYellow
            }
        }
        Write-Host ''
        Write-Host ("  Odswiezono: {0}   (co {1}s)" -f (Get-Date -Format 'HH:mm:ss'), $interval) -ForegroundColor DarkGray
        Start-Sleep -Seconds $interval
    }
    [Console]::ReadKey($true) | Out-Null
}

function Show-RecentReading {
    $machine = if ($script:Machines.Count -gt 0) { $script:Machines[0] } else { 'WELD-CELL-07' }
    $sel = Read-Host ("  ID maszyny [{0}]" -f $machine)
    if (-not [string]::IsNullOrWhiteSpace($sel)) { $machine = $sel }
    $take = Read-IntOr -Prompt '  Ile ostatnich odczytow?' -Default 15
    try {
        Get-RecentReading -BaseUrl $script:BaseUrl -MachineId $machine -Take $take |
            Select-Object recordedAtUtc, state, temperatureC, partsProduced, partsRejected |
            Format-Table -AutoSize
    }
    catch {
        Write-Host ("  Brak odczytow dla {0}" -f $machine) -ForegroundColor Yellow
    }
}

function Read-TargetChoice {
    Write-Host '  [a] Azure    [l] Local    [u] Wlasny URL    [t] Pobierz URL z Terraform'
    $choice = (Read-Host '  Wybierz').ToLower()
    switch ($choice) {
        'a' { $script:TargetName = 'Azure'; $script:BaseUrl = $script:Cfg.AzureBaseUrl }
        'l' { $script:TargetName = 'Local'; $script:BaseUrl = $script:Cfg.LocalBaseUrl }
        'u' {
            $url = Read-Host '  Podaj URL (np. https://...)'
            if (-not [string]::IsNullOrWhiteSpace($url)) { $script:BaseUrl = $url.Trim(); $script:TargetName = 'Custom' }
        }
        't' {
            try {
                $url = terraform -chdir="$PSScriptRoot/../infra" output -raw app_service_url 2>$null
                if (-not [string]::IsNullOrWhiteSpace($url)) {
                    $script:BaseUrl = $url.Trim(); $script:TargetName = 'Azure (tf)'
                    Write-Host ("  Ustawiono: {0}" -f $script:BaseUrl) -ForegroundColor Green
                }
                else { Write-Host '  Nie udalo sie pobrac URL z Terraform.' -ForegroundColor Yellow }
            }
            catch { Write-Host '  Terraform niedostepny lub brak stanu.' -ForegroundColor Yellow }
        }
        default { Write-Host '  Bez zmian.' -ForegroundColor DarkGray }
    }
}

function Invoke-QualityGate {
    & "$PSScriptRoot/Invoke-StaticAnalysis.ps1"
}

# --------------------------- Azure lifecycle -----------------------------
# These options drive the live Azure environment: Terraform provisions/destroys
# the infrastructure, and the Azure CLI deploys the app and starts/stops the Web App.
# Both `az` (logged in via `az login`) and `terraform` must be on PATH.

function Get-InfraPath {
    (Resolve-Path (Join-Path $PSScriptRoot '..\infra')).Path
}

function Test-AzureTooling {
    <# Verify az / terraform are available; print install hints if not. #>
    param([switch]$RequireTerraform)
    $az = [bool](Get-Command az -ErrorAction SilentlyContinue)
    $tf = [bool](Get-Command terraform -ErrorAction SilentlyContinue)
    if (-not $az) {
        Write-Host '  Azure CLI (az) nie jest dostepne w PATH.' -ForegroundColor Yellow
        Write-Host '  Instalacja: winget install Microsoft.AzureCLI   potem: az login' -ForegroundColor DarkGray
    }
    if ($RequireTerraform -and -not $tf) {
        Write-Host '  Terraform nie jest dostepny w PATH.' -ForegroundColor Yellow
        Write-Host '  Instalacja: winget install HashiCorp.Terraform' -ForegroundColor DarkGray
    }
    [pscustomobject]@{ Az = $az; Terraform = $tf }
}

function Get-SqlAdminPassword {
    <# Read the SQL admin password from $env:SQL_ADMIN_PASSWORD or a secure prompt. #>
    if ($env:SQL_ADMIN_PASSWORD) {
        Write-Host '  (uzywam hasla z $env:SQL_ADMIN_PASSWORD)' -ForegroundColor DarkGray
        return $env:SQL_ADMIN_PASSWORD
    }
    $secure = Read-Host '  Haslo administratora SQL (sql_admin_password)' -AsSecureString
    if (-not $secure -or $secure.Length -eq 0) { return $null }
    ([pscredential]::new('sqladmin', $secure)).GetNetworkCredential().Password
}

function Resolve-AzureTargetOrTf {
    <# Prefer live `terraform output`; fall back to config / URL resolution. #>
    $rg = $null
    $app = $null
    if (Get-Command terraform -ErrorAction SilentlyContinue) {
        $infra = Get-InfraPath
        try {
            $rg = terraform -chdir="$infra" output -raw resource_group_name 2>$null
            $app = terraform -chdir="$infra" output -raw app_service_name 2>$null
        }
        catch {
            Write-Verbose "terraform output unavailable: $($_.Exception.Message)"
        }
    }
    if ([string]::IsNullOrWhiteSpace($rg) -or [string]::IsNullOrWhiteSpace($app)) {
        $fallback = Resolve-AzureTarget -Config $script:Cfg -BaseUrl $script:BaseUrl
        if ([string]::IsNullOrWhiteSpace($rg)) { $rg = $fallback.ResourceGroup }
        if ([string]::IsNullOrWhiteSpace($app)) { $app = $fallback.AppServiceName }
    }
    [pscustomobject]@{
        ResourceGroup  = if ([string]::IsNullOrWhiteSpace($rg)) { $null } else { $rg.Trim() }
        AppServiceName = if ([string]::IsNullOrWhiteSpace($app)) { $null } else { $app.Trim() }
    }
}

function Update-ConfigAzureUrl {
    <# Persist a freshly provisioned Azure URL back into FactoryTelemetry.config.psd1. #>
    [CmdletBinding(SupportsShouldProcess)]
    param([Parameter(Mandatory)][string]$Url)
    $path = Join-Path $PSScriptRoot 'FactoryTelemetry.config.psd1'
    if (-not (Test-Path -Path $path)) { return }
    if (-not $PSCmdlet.ShouldProcess($path, "Set AzureBaseUrl = $Url")) { return }
    $content = Get-Content -Path $path -Raw
    $escaped = $Url -replace '\$', '$$$$'
    $updated = $content -replace "(?m)^(\s*AzureBaseUrl\s*=\s*')[^']*(')", ('${1}' + $escaped + '${2}')
    Set-Content -Path $path -Value $updated -Encoding UTF8
    Write-Host ("  Zapisano AzureBaseUrl w configu: {0}" -f $Url) -ForegroundColor DarkGray
}

function Invoke-AzureProvision {
    $tools = Test-AzureTooling -RequireTerraform
    if (-not $tools.Terraform -or -not $tools.Az) { return }
    Write-Host '  Provisioning infrastruktury Azure (Terraform)...' -ForegroundColor Cyan
    Write-Host '  Wymaga: az login + zainicjowany backend (patrz infra/README.md).' -ForegroundColor DarkGray
    $sqlPwd = Get-SqlAdminPassword
    if ([string]::IsNullOrWhiteSpace($sqlPwd)) { Write-Host '  Anulowano (brak hasla).' -ForegroundColor Yellow; return }
    $infra = Get-InfraPath
    terraform -chdir="$infra" apply -var "sql_admin_password=$sqlPwd"
    if ($LASTEXITCODE -ne 0) {
        Write-Host '  Terraform apply zakonczony bledem (sprawdz az login / backend).' -ForegroundColor Red
        return
    }
    $url = terraform -chdir="$infra" output -raw app_service_url 2>$null
    if (-not [string]::IsNullOrWhiteSpace($url)) {
        $script:BaseUrl = $url.Trim()
        $script:TargetName = 'Azure (tf)'
        Update-ConfigAzureUrl -Url $script:BaseUrl
        Write-Host ("  Infrastruktura gotowa. URL API: {0}" -f $script:BaseUrl) -ForegroundColor Green
    }
    $deploy = Read-Host '  Wdrozyc teraz kod aplikacji na App Service? (t/N)'
    if ($deploy -match '^[tTyY]') { Invoke-AzureDeploy }
}

function Invoke-AzureDeploy {
    $tools = Test-AzureTooling
    if (-not $tools.Az) { return }
    $target = Resolve-AzureTargetOrTf
    if (-not $target.ResourceGroup -or -not $target.AppServiceName) {
        Write-Host '  Nie udalo sie ustalic grupy zasobow / nazwy App Service.' -ForegroundColor Yellow
        return
    }
    $root = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
    $proj = Join-Path $root 'src/FactoryTelemetry.Api'
    $publish = Join-Path $root 'publish'
    $zip = Join-Path $root 'app.zip'

    Write-Host '  dotnet publish (Release)...' -ForegroundColor Cyan
    dotnet publish $proj -c Release -o $publish
    if ($LASTEXITCODE -ne 0) { Write-Host '  Publish nieudany.' -ForegroundColor Red; return }

    # Pack with tar (forward slashes): Compress-Archive on Win PS writes backslash entries
    # that Linux App Service cannot extract -> the app fails to find Microsoft.Data.SqlClient.
    Write-Host '  Pakowanie artefaktu (tar)...' -ForegroundColor Cyan
    if (Test-Path -Path $zip) { Remove-Item -Path $zip -Force }
    tar -a -c -f $zip -C $publish .
    if ($LASTEXITCODE -ne 0) { Write-Host '  Pakowanie nieudane.' -ForegroundColor Red; return }

    Write-Host ("  Deploy do {0} / {1}..." -f $target.ResourceGroup, $target.AppServiceName) -ForegroundColor Cyan
    az webapp deploy -g $target.ResourceGroup -n $target.AppServiceName --src-path $zip --type zip
    if ($LASTEXITCODE -eq 0) { Write-Host '  Wdrozenie zakonczone.' -ForegroundColor Green }
    else { Write-Host '  Wdrozenie nieudane (sprawdz az login / nazwy zasobow).' -ForegroundColor Red }
}

function Invoke-AzureWebAppPower {
    param([Parameter(Mandatory)][ValidateSet('start', 'stop')][string]$Action)
    $tools = Test-AzureTooling
    if (-not $tools.Az) { return }
    $target = Resolve-AzureTargetOrTf
    if (-not $target.ResourceGroup -or -not $target.AppServiceName) {
        Write-Host '  Nie udalo sie ustalic grupy zasobow / nazwy App Service.' -ForegroundColor Yellow
        return
    }
    $verb = if ($Action -eq 'start') { 'Uruchamiam' } else { 'Zatrzymuje' }
    Write-Host ("  {0} App Service {1}..." -f $verb, $target.AppServiceName) -ForegroundColor Cyan
    az webapp $Action -g $target.ResourceGroup -n $target.AppServiceName
    if ($LASTEXITCODE -ne 0) {
        Write-Host '  Operacja nieudana (sprawdz az login / nazwy zasobow).' -ForegroundColor Red
        return
    }
    Write-Host '  OK.' -ForegroundColor Green
    if ($Action -eq 'stop') {
        Write-Host '  Uwaga: stop wstrzymuje aplikacje, ale plan App Service (B1) nadal generuje koszt.' -ForegroundColor DarkYellow
        Write-Host '  Aby calkowicie zwolnic creditsy, uzyj opcji [5] - usun wszystkie zasoby.' -ForegroundColor DarkYellow
    }
}

function Invoke-AzureDestroy {
    $tools = Test-AzureTooling -RequireTerraform
    if (-not $tools.Terraform) { return }
    Write-Host '  UWAGA: ta operacja USUNIE wszystkie zasoby Azure' -ForegroundColor Red
    Write-Host '         (App Service, SQL, IoT Hub, ACR, observability).' -ForegroundColor Red
    Write-Host '  To wlasnie ona zwalnia creditsy - stan Terraform zostanie pusty.' -ForegroundColor DarkYellow
    $confirm = Read-Host '  Wpisz DESTROY aby potwierdzic (cokolwiek innego anuluje)'
    if ($confirm -ne 'DESTROY') { Write-Host '  Anulowano.' -ForegroundColor DarkGray; return }
    $sqlPwd = Get-SqlAdminPassword
    if ([string]::IsNullOrWhiteSpace($sqlPwd)) { Write-Host '  Anulowano (brak hasla).' -ForegroundColor Yellow; return }
    $infra = Get-InfraPath
    terraform -chdir="$infra" destroy -var "sql_admin_password=$sqlPwd"
    if ($LASTEXITCODE -eq 0) { Write-Host '  Zasoby usuniete. Creditsy nie sa juz pobierane.' -ForegroundColor Green }
    else { Write-Host '  Destroy zakonczony bledem (byc moze zasoby juz nie istnieja).' -ForegroundColor Yellow }
}

function Show-AzureState {
    $tools = Test-AzureTooling
    if (-not $tools.Az) { return }
    $target = Resolve-AzureTargetOrTf
    if (-not $target.ResourceGroup) {
        Write-Host '  Brak znanej grupy zasobow (nic nie sprowizjonowano?).' -ForegroundColor Yellow
        return
    }
    Write-Host ("  Grupa zasobow: {0}" -f $target.ResourceGroup) -ForegroundColor Cyan
    $exists = az group exists -n $target.ResourceGroup 2>$null
    if ($exists -ne 'true') {
        Write-Host '  Grupa zasobow nie istnieje (zasoby usuniete lub jeszcze nieutworzone).' -ForegroundColor DarkYellow
        return
    }
    Write-Host '  Zasoby w grupie:' -ForegroundColor Cyan
    az resource list -g $target.ResourceGroup --query "[].{Nazwa:name, Typ:type, Region:location}" -o table
    if ($target.AppServiceName) {
        $state = az webapp show -g $target.ResourceGroup -n $target.AppServiceName --query state -o tsv 2>$null
        if (-not [string]::IsNullOrWhiteSpace($state)) {
            Write-Host ("  App Service '{0}' stan: {1}" -f $target.AppServiceName, $state.Trim()) -ForegroundColor Green
        }
    }
}

function Invoke-AzureMenu {
    do {
        Write-Host ''
        Write-Host '  --- Zarzadzanie infrastruktura Azure ---' -ForegroundColor Cyan
        Write-Host '  [1] Provisioning infrastruktury   (terraform apply [+ deploy])'
        Write-Host '  [2] Wdroz / aktualizuj aplikacje  (publish + az webapp deploy)'
        Write-Host '  [3] Wlacz aplikacje               (az webapp start)'
        Write-Host '  [4] Wylacz aplikacje              (az webapp stop)'
        Write-Host '  [5] USUN wszystkie zasoby         (terraform destroy)' -ForegroundColor Yellow
        Write-Host '  [6] Pokaz stan zasobow Azure'
        Write-Host '  [7] Zaloguj do Azure / ustaw haslo (az login)'
        Write-Host '  [0] Powrot do menu glownego'
        Write-Host ''
        $sub = Read-Host '  Wybierz opcje Azure'
        Write-Host ''
        try {
            switch ($sub) {
                '1' { Invoke-AzureProvision }
                '2' { Invoke-AzureDeploy }
                '3' { Invoke-AzureWebAppPower -Action start }
                '4' { Invoke-AzureWebAppPower -Action stop }
                '5' { Invoke-AzureDestroy }
                '6' { Show-AzureState }
                '7' { & "$PSScriptRoot/Connect-FactoryAzure.ps1" }
                '0' { }
                default { Write-Host '  Nieznana opcja.' -ForegroundColor Yellow }
            }
        }
        catch {
            Write-Host ("  Blad: {0}" -f $_.Exception.Message) -ForegroundColor Red
        }
        if ($sub -ne '0') {
            Write-Host ''
            Read-Host '  [Enter] - menu Azure' | Out-Null
        }
    } while ($sub -ne '0')
}

# ------------------------------- main loop -------------------------------
do {
    Show-Header
    Show-Menu
    $selection = Read-Host '  Wybierz opcje'
    Write-Host ''
    try {
        switch ($selection) {
            '1' { Invoke-HealthCheck }
            '2' { Invoke-Simulator }
            '3' { Invoke-Report }
            '4' { Invoke-Monitor }
            '5' { Show-RecentReading }
            '6' { Start-Process ("{0}/swagger" -f $script:BaseUrl.TrimEnd('/')) }
            '7' { Read-TargetChoice }
            '8' { Invoke-QualityGate }
            '9' { Invoke-AzureMenu }
            '0' { }
            default { Write-Host '  Nieznana opcja.' -ForegroundColor Yellow }
        }
    }
    catch {
        Write-Host ("  Blad: {0}" -f $_.Exception.Message) -ForegroundColor Red
    }
    if ($selection -ne '0' -and $selection -ne '4' -and $selection -ne '9') {
        Write-Host ''
        Read-Host '  [Enter] - powrot do menu' | Out-Null
    }
} while ($selection -ne '0')

Write-Host '  Do widzenia.' -ForegroundColor Cyan
