<#
.SYNOPSIS
    Quality gate for the PowerShell layer: PSScriptAnalyzer (lint) + Pester (tests).
.DESCRIPTION
    Run locally before committing or automatically in CI. Installs the required modules
    for the current user if they are missing, lints every script under /scripts, then runs
    the Pester suite and writes NUnit results for the pipeline to publish.
.EXAMPLE
    pwsh ./scripts/Invoke-StaticAnalysis.ps1
#>
[CmdletBinding()]
param(
    [string]$Path = "$PSScriptRoot",
    [string]$TestPath = "$PSScriptRoot/tests",
    [string]$ResultsFile = "$PSScriptRoot/tests/pester-results.xml",
    [string]$SettingsPath = "$PSScriptRoot/PSScriptAnalyzerSettings.psd1"
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

function Install-IfMissing {
    param([string]$Name, [version]$MinimumVersion)
    $existing = Get-Module -ListAvailable -Name $Name |
        Where-Object { $_.Version -ge $MinimumVersion } | Select-Object -First 1
    if (-not $existing) {
        Write-Host "Installing $Name >= $MinimumVersion ..." -ForegroundColor Yellow
        Install-Module -Name $Name -MinimumVersion $MinimumVersion -Scope CurrentUser -Force -SkipPublisherCheck
    }
}

Install-IfMissing -Name PSScriptAnalyzer -MinimumVersion '1.21.0'
Install-IfMissing -Name Pester -MinimumVersion '5.5.0'

# --- 1. Static analysis --------------------------------------------------------
Write-Host '== PSScriptAnalyzer ==' -ForegroundColor Cyan
Import-Module PSScriptAnalyzer -Force
$findings = @(Invoke-ScriptAnalyzer -Path $Path -Recurse -Settings $SettingsPath -Severity Warning, Error)

if ($findings) {
    $findings | Format-Table -AutoSize RuleName, Severity, ScriptName, Line, Message | Out-String | Write-Host
    $errors = @($findings | Where-Object Severity -eq 'Error')
    if ($errors.Count -gt 0) {
        throw "PSScriptAnalyzer found $($errors.Count) error(s)."
    }
    Write-Warning "PSScriptAnalyzer reported $($findings.Count) warning(s)."
}
else {
    Write-Host 'No issues found.' -ForegroundColor Green
}

# --- 2. Pester tests -----------------------------------------------------------
Write-Host '== Pester ==' -ForegroundColor Cyan
Import-Module Pester -Force

$config = New-PesterConfiguration
$config.Run.Path = $TestPath
$config.Run.Exit = $true
$config.Output.Verbosity = 'Detailed'
$config.TestResult.Enabled = $true
$config.TestResult.OutputFormat = 'NUnitXml'
$config.TestResult.OutputPath = $ResultsFile

Invoke-Pester -Configuration $config
