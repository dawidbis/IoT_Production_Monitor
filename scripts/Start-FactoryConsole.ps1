<#
.SYNOPSIS
    Interactive operator console for the Factory Telemetry & OEE Monitor.
.DESCRIPTION
    One entry point (wrapped by FactoryTelemetry.bat) to drive the running API (local or Azure).
    Lets the developer check health, stream simulated telemetry, pull OEE reports, watch a live
    monitor, browse recent readings, open Swagger, switch environment, and run the quality gate.
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
            '0' { }
            default { Write-Host '  Nieznana opcja.' -ForegroundColor Yellow }
        }
    }
    catch {
        Write-Host ("  Blad: {0}" -f $_.Exception.Message) -ForegroundColor Red
    }
    if ($selection -ne '0' -and $selection -ne '4') {
        Write-Host ''
        Read-Host '  [Enter] - powrot do menu' | Out-Null
    }
} while ($selection -ne '0')

Write-Host '  Do widzenia.' -ForegroundColor Cyan
