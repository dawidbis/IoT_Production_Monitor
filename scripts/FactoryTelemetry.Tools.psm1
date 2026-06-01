<#
.SYNOPSIS
    Reusable helper functions for the Factory Telemetry & OEE Monitor.
.DESCRIPTION
    Pure, testable functions for building telemetry payloads, posting them to the API
    and rendering OEE reports. Imported by the thin wrapper scripts and by the Pester tests.
    Cross-platform (Windows PowerShell 5.1 and PowerShell 7+).
#>

Set-StrictMode -Version Latest

$script:ValidStates = @('Running', 'Idle', 'Down', 'PlannedStop')

function New-TelemetryPayload {
    <#
    .SYNOPSIS
        Build a single, validated telemetry payload object.
    .EXAMPLE
        New-TelemetryPayload -MachineId 'WELD-CELL-07' -State Running -TemperatureC 72 -PartsProduced 12 -PartsRejected 1
    #>
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseShouldProcessForStateChangingFunctions', '',
        Justification = 'Pure factory function: returns an object, changes no system state.')]
    [CmdletBinding()]
    [OutputType([pscustomobject])]
    param(
        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string]$MachineId,

        [Parameter(Mandatory)]
        [ValidateSet('Running', 'Idle', 'Down', 'PlannedStop')]
        [string]$State,

        [ValidateRange(-50, 500)]
        [double]$TemperatureC = 20,

        [ValidateRange(0, [int]::MaxValue)]
        [int]$PartsProduced = 0,

        [ValidateRange(0, [int]::MaxValue)]
        [int]$PartsRejected = 0
    )

    if ($PartsRejected -gt $PartsProduced) {
        throw "PartsRejected ($PartsRejected) cannot exceed PartsProduced ($PartsProduced)."
    }

    [pscustomobject]@{
        machineId     = $MachineId
        state         = $State
        temperatureC  = $TemperatureC
        partsProduced = $PartsProduced
        partsRejected = $PartsRejected
    }
}

function New-RandomTelemetryPayload {
    <#
    .SYNOPSIS
        Generate a realistic, randomised telemetry payload for a machine (shop-floor simulator).
    #>
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseShouldProcessForStateChangingFunctions', '',
        Justification = 'Pure factory function: returns an object, changes no system state.')]
    [CmdletBinding()]
    [OutputType([pscustomobject])]
    param(
        [Parameter(Mandatory)]
        [string]$MachineId
    )

    # Weighted towards Running to mimic a healthy line.
    $state = Get-Random -InputObject @('Running', 'Running', 'Running', 'Idle', 'Down', 'PlannedStop')

    $produced = if ($state -eq 'Running') { Get-Random -Minimum 1 -Maximum 6 } else { 0 }
    $rejected = if ($produced -gt 0 -and (Get-Random -Minimum 0 -Maximum 100) -lt 8) { 1 } else { 0 }
    $temp = [math]::Round((Get-Random -Minimum 55.0 -Maximum 85.0), 1)

    New-TelemetryPayload -MachineId $MachineId -State $state -TemperatureC $temp `
        -PartsProduced $produced -PartsRejected $rejected
}

function Send-Telemetry {
    <#
    .SYNOPSIS
        POST a telemetry payload to the API ingestion endpoint.
    #>
    [CmdletBinding(SupportsShouldProcess)]
    param(
        [Parameter(Mandatory)]
        [string]$BaseUrl,

        [Parameter(Mandatory, ValueFromPipeline)]
        [pscustomobject]$Payload
    )
    process {
        $uri = "$($BaseUrl.TrimEnd('/'))/api/telemetry"
        if ($PSCmdlet.ShouldProcess($uri, 'POST telemetry')) {
            Invoke-RestMethod -Uri $uri -Method Post -Body ($Payload | ConvertTo-Json) `
                -ContentType 'application/json'
        }
    }
}

function Get-MachineOee {
    <#
    .SYNOPSIS
        Retrieve the computed OEE for a machine from the API.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$BaseUrl,

        [Parameter(Mandatory)]
        [string]$MachineId
    )
    $uri = "$($BaseUrl.TrimEnd('/'))/api/machines/$MachineId/oee"
    Invoke-RestMethod -Uri $uri -Method Get
}

function Format-OeeReport {
    <#
    .SYNOPSIS
        Render an OEE result object as a readable console report.
    #>
    [CmdletBinding()]
    [OutputType([string])]
    param(
        [Parameter(Mandatory, ValueFromPipeline)]
        [pscustomobject]$Oee
    )
    process {
        $pct = { param($v) '{0,6:P1}' -f $v }
        @"
OEE report for $($Oee.machineId)
  Availability : $(& $pct $Oee.availability)
  Performance  : $(& $pct $Oee.performance)
  Quality      : $(& $pct $Oee.quality)
  ----------------------------------------
  OEE          : $(& $pct $Oee.oee)
  Samples      : $($Oee.sampleCount)  |  Produced: $($Oee.totalPartsProduced)  Rejected: $($Oee.totalPartsRejected)
"@
    }
}

Export-ModuleMember -Function New-TelemetryPayload, New-RandomTelemetryPayload, Send-Telemetry, Get-MachineOee, Format-OeeReport
