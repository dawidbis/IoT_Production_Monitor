<#
.SYNOPSIS
    Shop-floor simulator: streams randomised telemetry to the API for one or more machines.
.DESCRIPTION
    Mimics robotic welding cells / presses emitting heartbeats. Useful for demos and for
    populating data before querying the OEE endpoint.
.EXAMPLE
    ./New-SampleTelemetry.ps1 -BaseUrl http://localhost:5000 -Machines WELD-CELL-07,PRESS-12 -Count 30 -DelayMs 200
#>
[CmdletBinding(SupportsShouldProcess)]
param(
    [string]$BaseUrl,

    [string[]]$Machines,

    [ValidateRange(1, 100000)]
    [int]$Count = 20,

    [ValidateRange(0, 60000)]
    [int]$DelayMs = 250
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

Import-Module "$PSScriptRoot/FactoryTelemetry.Tools.psm1" -Force

# Default to the configured Azure target unless overridden on the command line.
$cfg = Get-FactoryConfig
if (-not $BaseUrl) { $BaseUrl = $cfg.AzureBaseUrl }
if (-not $Machines) { $Machines = $cfg.Machines }

Write-Host "Streaming $Count samples per machine to $BaseUrl ..." -ForegroundColor Cyan

for ($i = 1; $i -le $Count; $i++) {
    foreach ($machine in $Machines) {
        $payload = New-RandomTelemetryPayload -MachineId $machine
        if ($PSCmdlet.ShouldProcess($machine, "send sample $i")) {
            $null = $payload | Send-Telemetry -BaseUrl $BaseUrl
            Write-Host ("[{0,3}/{1}] {2,-14} {3,-11} produced={4} rejected={5}" -f `
                    $i, $Count, $machine, $payload.state, $payload.partsProduced, $payload.partsRejected)
        }
    }
    if ($DelayMs -gt 0) { Start-Sleep -Milliseconds $DelayMs }
}

Write-Host 'Done.' -ForegroundColor Green
