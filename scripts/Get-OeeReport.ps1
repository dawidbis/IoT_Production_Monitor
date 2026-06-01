<#
.SYNOPSIS
    Fetch and print the OEE report for one or more machines.
.EXAMPLE
    ./Get-OeeReport.ps1 -BaseUrl http://localhost:5000 -Machines WELD-CELL-07,PRESS-12
#>
[CmdletBinding()]
param(
    [string]$BaseUrl,
    [string[]]$Machines
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

Import-Module "$PSScriptRoot/FactoryTelemetry.Tools.psm1" -Force

# Default to the configured Azure target unless overridden on the command line.
$cfg = Get-FactoryConfig
if (-not $BaseUrl) { $BaseUrl = $cfg.AzureBaseUrl }
if (-not $Machines) { $Machines = $cfg.Machines }

foreach ($machine in $Machines) {
    try {
        Get-MachineOee -BaseUrl $BaseUrl -MachineId $machine | Format-OeeReport
    }
    catch {
        Write-Warning "Could not retrieve OEE for '$machine': $($_.Exception.Message)"
    }
}
