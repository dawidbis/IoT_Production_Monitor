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

Describe 'Format-OeeLine' {

    It 'renders a single compact line with machine id and OEE' {
        $oee = [pscustomobject]@{
            machineId = 'PRESS-12'; availability = 0.7; performance = 1.0; quality = 1.0
            oee = 0.7; totalPartsProduced = 20; totalPartsRejected = 0; sampleCount = 12
        }

        $line = $oee | Format-OeeLine

        $line | Should -Match 'PRESS-12'
        $line | Should -Match 'OEE'
        ($line -split "`n").Count | Should -Be 1
    }
}

Describe 'Get-FactoryConfig' {

    It 'loads the central config with the expected keys' {
        $cfg = Get-FactoryConfig

        $cfg.AzureBaseUrl  | Should -Not -BeNullOrEmpty
        $cfg.LocalBaseUrl  | Should -Not -BeNullOrEmpty
        $cfg.Machines      | Should -Not -BeNullOrEmpty
        $cfg.DefaultTarget | Should -BeIn @('Azure', 'Local')
    }
}

Describe 'Get-AppNameFromUrl' {

    It 'extracts the App Service name from a full Azure URL' {
        Get-AppNameFromUrl -Url 'https://app-factorytel-dev-hnzv6.azurewebsites.net' |
            Should -Be 'app-factorytel-dev-hnzv6'
    }

    It 'handles a bare host without a scheme' {
        Get-AppNameFromUrl -Url 'app-foo.azurewebsites.net' | Should -Be 'app-foo'
    }

    It 'ignores a trailing path' {
        Get-AppNameFromUrl -Url 'https://app-bar.azurewebsites.net/swagger' | Should -Be 'app-bar'
    }

    It 'returns nothing for empty input' {
        Get-AppNameFromUrl -Url '' | Should -BeNullOrEmpty
    }
}

Describe 'Resolve-AzureTarget' {

    It 'prefers explicit config values over the URL' {
        $cfg = @{ AzureResourceGroup = 'rg-x'; AzureAppServiceName = 'app-x' }
        $t = Resolve-AzureTarget -Config $cfg -BaseUrl 'https://app-y.azurewebsites.net'

        $t.ResourceGroup  | Should -Be 'rg-x'
        $t.AppServiceName | Should -Be 'app-x'
    }

    It 'falls back to the app name parsed from the URL' {
        $cfg = @{ AzureResourceGroup = 'rg-x' }
        $t = Resolve-AzureTarget -Config $cfg -BaseUrl 'https://app-y.azurewebsites.net'

        $t.ResourceGroup  | Should -Be 'rg-x'
        $t.AppServiceName | Should -Be 'app-y'
    }

    It 'returns a null resource group when nothing is known' {
        $t = Resolve-AzureTarget -Config @{} -BaseUrl 'https://app-y.azurewebsites.net'

        $t.ResourceGroup  | Should -BeNullOrEmpty
        $t.AppServiceName | Should -Be 'app-y'
    }
}
