<#
.SYNOPSIS
    Pre-flight for the Azure lifecycle menu: ensure `az login` + the SQL admin password.
.DESCRIPTION
    Convenience helper to run once per terminal session before using the operator console's
    "[9] Zarzadzanie Azure" menu. It:
      1. checks the Azure CLI is installed,
      2. signs in if you are not already logged in (the single default subscription is used
         automatically - no `az account set` needed),
      3. sets $env:SQL_ADMIN_PASSWORD for the session so Terraform / the console pick it up
         without prompting.

    Run it in the SAME terminal you launch the console from: $env:SQL_ADMIN_PASSWORD is a
    process environment variable, so child processes (the .bat launcher, terraform, az)
    inherit it. The console's [9] -> [7] option calls this script for you.
.PARAMETER StartConsole
    After a successful sign-in, launch the operator console in this same session.
.EXAMPLE
    ./scripts/Connect-FactoryAzure.ps1
.EXAMPLE
    ./scripts/Connect-FactoryAzure.ps1 -StartConsole
#>
[CmdletBinding()]
param(
    [switch]$StartConsole
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

if (-not (Get-Command az -ErrorAction SilentlyContinue)) {
    Write-Host 'Azure CLI (az) nie jest dostepne w PATH.' -ForegroundColor Red
    Write-Host 'Instalacja: winget install Microsoft.AzureCLI' -ForegroundColor DarkGray
    return
}

# `az account show` exits non-zero when no one is signed in.
$null = az account show 2>$null
if ($LASTEXITCODE -ne 0) {
    Write-Host 'Logowanie do Azure...' -ForegroundColor Cyan
    az login
    $null = az account show 2>$null
}
if ($LASTEXITCODE -ne 0) {
    Write-Host 'Nie udalo sie zalogowac do Azure.' -ForegroundColor Red
    return
}

$sub = az account show --query name -o tsv 2>$null
$user = az account show --query user.name -o tsv 2>$null
if ($sub) { $sub = $sub.Trim() }
if ($user) { $user = $user.Trim() }
Write-Host ("Zalogowano: {0}  (subskrypcja: {1})" -f $user, $sub) -ForegroundColor Green

# SQL admin password for Terraform (the sql_admin_password variable has no default).
if ([string]::IsNullOrWhiteSpace($env:SQL_ADMIN_PASSWORD)) {
    $secure = Read-Host 'Haslo administratora SQL (min. 8 znakow: duze+male+cyfra)' -AsSecureString
    if ($secure -and $secure.Length -gt 0) {
        $env:SQL_ADMIN_PASSWORD = ([pscredential]::new('sqladmin', $secure)).GetNetworkCredential().Password
        Write-Host 'Ustawiono $env:SQL_ADMIN_PASSWORD dla tej sesji.' -ForegroundColor Green
    }
    else {
        Write-Host 'Pominieto haslo - konsola zapyta o nie przy provisioningu.' -ForegroundColor DarkYellow
    }
}
else {
    Write-Host '$env:SQL_ADMIN_PASSWORD juz ustawione - uzywam istniejacego.' -ForegroundColor DarkGray
}

Write-Host ''
Write-Host 'Gotowe. Uruchom konsole -> [9] Zarzadzanie Azure -> [1] Provisioning.' -ForegroundColor Cyan

if ($StartConsole) {
    & "$PSScriptRoot/Start-FactoryConsole.ps1"
}
