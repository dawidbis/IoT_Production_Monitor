<#
    Pester v5 tests for the FactoryTelemetry.Tools module.
    Run via: pwsh ../Invoke-StaticAnalysis.ps1   (or)   Invoke-Pester
#>

BeforeAll {
    $modulePath = Join-Path (Split-Path $PSScriptRoot -Parent) 'FactoryTelemetry.Tools.psm1'
    Import-Module $modulePath -Force
}

Describe 'New-TelemetryPayload' {

    It 'builds a payload with the expected shape' {
        $p = New-TelemetryPayload -MachineId 'WELD-CELL-07' -State Running `
            -TemperatureC 72 -PartsProduced 12 -PartsRejected 1

        $p.machineId     | Should -Be 'WELD-CELL-07'
        $p.state         | Should -Be 'Running'
        $p.temperatureC  | Should -Be 72
        $p.partsProduced | Should -Be 12
        $p.partsRejected | Should -Be 1
    }

    It 'throws when rejected parts exceed produced parts' {
        { New-TelemetryPayload -MachineId 'M1' -State Running -PartsProduced 2 -PartsRejected 5 } |
            Should -Throw '*cannot exceed*'
    }

    It 'rejects an invalid machine state' {
        { New-TelemetryPayload -MachineId 'M1' -State 'Exploding' } | Should -Throw
    }

    It 'rejects an implausible temperature' {
        { New-TelemetryPayload -MachineId 'M1' -State Running -TemperatureC 9000 } | Should -Throw
    }
}

Describe 'New-RandomTelemetryPayload' {

    It 'always produces a valid payload (100 iterations)' {
        $valid = @('Running', 'Idle', 'Down', 'PlannedStop')
        1..100 | ForEach-Object {
            $p = New-RandomTelemetryPayload -MachineId 'PRESS-12'
            $p.state         | Should -BeIn $valid
            $p.partsRejected | Should -BeLessOrEqual $p.partsProduced
            $p.temperatureC  | Should -BeGreaterThan 0
        }
    }
}

Describe 'Format-OeeReport' {

    It 'renders the key OEE factors' {
        $oee = [pscustomobject]@{
            machineId          = 'WELD-CELL-07'
            availability       = 0.75
            performance        = 1.0
            quality            = 0.95
            oee                = 0.7125
            sampleCount        = 10
            totalPartsProduced = 20
            totalPartsRejected = 1
        }

        $report = $oee | Format-OeeReport

        $report | Should -Match 'WELD-CELL-07'
        $report | Should -Match 'Availability'
        $report | Should -Match 'OEE'
    }
}
