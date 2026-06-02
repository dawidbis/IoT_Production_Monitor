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

function Format-OeeLine {
    <#
    .SYNOPSIS
        Render an OEE result as a single compact line (for the live monitor).
    #>
    [CmdletBinding()]
    [OutputType([string])]
    param(
        [Parameter(Mandatory, ValueFromPipeline)]
        [pscustomobject]$Oee
    )
    process {
        '{0,-14} OEE {1,5:P0}   A {2,4:P0}  P {3,4:P0}  Q {4,4:P0}   prod {5}  rej {6}  n={7}' -f `
            $Oee.machineId, $Oee.oee, $Oee.availability, $Oee.performance, $Oee.quality, `
            $Oee.totalPartsProduced, $Oee.totalPartsRejected, $Oee.sampleCount
    }
}

function Get-FactoryConfig {
    <#
    .SYNOPSIS
        Load central configuration (Azure/local URLs, machine list) from FactoryTelemetry.config.psd1.
    #>
    [CmdletBinding()]
    [OutputType([hashtable])]
    param()
    $path = Join-Path $PSScriptRoot 'FactoryTelemetry.config.psd1'
    if (Test-Path -Path $path) {
        Import-PowerShellDataFile -Path $path
    }
    else {
        @{
            AzureBaseUrl  = 'http://localhost:5150'
            LocalBaseUrl  = 'http://localhost:5150'
            DefaultTarget = 'Local'
            Machines      = @('WELD-CELL-07', 'PRESS-12')
        }
    }
}

function Test-FactoryHealth {
    <#
    .SYNOPSIS
        Probe the API /health endpoint; never throws (returns a status object).
    #>
    [CmdletBinding()]
    [OutputType([pscustomobject])]
    param(
        [Parameter(Mandatory)]
        [string]$BaseUrl,

        [ValidateRange(1, 60)]
        [int]$TimeoutSec = 8
    )
    try {
        $r = Invoke-RestMethod -Uri "$($BaseUrl.TrimEnd('/'))/health" -Method Get -TimeoutSec $TimeoutSec
        [pscustomobject]@{ Healthy = ($r.status -eq 'Healthy'); Status = $r.status; Utc = $r.utc }
    }
    catch {
        [pscustomobject]@{ Healthy = $false; Status = "ERROR: $($_.Exception.Message)"; Utc = $null }
    }
}

function Get-AppNameFromUrl {
    <#
    .SYNOPSIS
        Extract the App Service name from an Azure Web App URL (or bare host).
    .DESCRIPTION
        Pure helper used by the console's Azure lifecycle menu to derive the App
        Service name (e.g. 'app-factorytel-dev-hnzv6') from its public URL when no
        explicit name is configured. Returns $null for empty input.
    .EXAMPLE
        Get-AppNameFromUrl -Url 'https://app-factorytel-dev-hnzv6.azurewebsites.net'
        # -> app-factorytel-dev-hnzv6
    #>
    [CmdletBinding()]
    [OutputType([string])]
    param(
        [string]$Url
    )

    if ([string]::IsNullOrWhiteSpace($Url)) { return $null }

    $hostName = $Url.Trim()
    try {
        $uri = [Uri]$hostName
        if ($uri.IsAbsoluteUri) { $hostName = $uri.Host }
    }
    catch {
        # Not an absolute URI; treat the input itself as a host name.
        Write-Verbose "Get-AppNameFromUrl: '$Url' is not an absolute URI."
    }

    $first = $hostName.Split('/')[0].Split('.')[0]
    if ([string]::IsNullOrWhiteSpace($first)) { return $null }
    $first
}

function Resolve-AzureTarget {
    <#
    .SYNOPSIS
        Resolve the Azure resource group + App Service name from config and base URL.
    .DESCRIPTION
        Pure helper: explicit config values win; the App Service name falls back to the
        one parsed from the base URL. Live values from `terraform output` are layered on
        top by the console before this is consulted, so this is the offline fallback.
    #>
    [CmdletBinding()]
    [OutputType([pscustomobject])]
    param(
        [Parameter(Mandatory)]
        [hashtable]$Config,

        [string]$BaseUrl
    )

    $rg = if ($Config.Contains('AzureResourceGroup')) { [string]$Config['AzureResourceGroup'] } else { '' }
    $app = if ($Config.Contains('AzureAppServiceName')) { [string]$Config['AzureAppServiceName'] } else { '' }

    if ([string]::IsNullOrWhiteSpace($app) -and -not [string]::IsNullOrWhiteSpace($BaseUrl)) {
        $app = Get-AppNameFromUrl -Url $BaseUrl
    }

    [pscustomobject]@{
        ResourceGroup  = if ([string]::IsNullOrWhiteSpace($rg)) { $null } else { $rg }
        AppServiceName = if ([string]::IsNullOrWhiteSpace($app)) { $null } else { $app }
    }
}

function Get-RecentReading {
    <#
    .SYNOPSIS
        Fetch the most recent telemetry readings for a machine.
    #>
    [CmdletBinding()]
    [OutputType([pscustomobject])]
    param(
        [Parameter(Mandatory)]
        [string]$BaseUrl,

        [Parameter(Mandatory)]
        [string]$MachineId,

        [ValidateRange(1, 500)]
        [int]$Take = 20
    )
    Invoke-RestMethod -Uri "$($BaseUrl.TrimEnd('/'))/api/telemetry/$MachineId`?take=$Take" -Method Get
}

Export-ModuleMember -Function New-TelemetryPayload, New-RandomTelemetryPayload, Send-Telemetry,
Get-MachineOee, Format-OeeReport, Format-OeeLine, Get-FactoryConfig, Test-FactoryHealth, Get-RecentReading,
Get-AppNameFromUrl, Resolve-AzureTarget
