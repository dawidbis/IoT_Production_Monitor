@{
    # Central configuration for the helper scripts and the interactive console.
    # Update AzureBaseUrl after a redeploy (or use the console's "refresh from Terraform" option).

    AzureBaseUrl  = 'https://app-factorytel-dev-hnzv6.azurewebsites.net'
    LocalBaseUrl  = 'http://localhost:5150'

    # Which target the scripts/console use by default: 'Azure' or 'Local'.
    DefaultTarget = 'Azure'

    # Machines used by the simulator and reports.
    Machines      = @('WELD-CELL-07', 'PRESS-12')
}
