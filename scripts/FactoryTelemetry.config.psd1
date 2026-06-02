@{
    # Central configuration for the helper scripts and the interactive console.
    # Update AzureBaseUrl after a redeploy (or use the console's "refresh from Terraform" option).

    AzureBaseUrl        = 'https://app-factorytel-dev-hnzv6.azurewebsites.net'
    LocalBaseUrl        = 'http://localhost:5150'

    # Which target the scripts/console use by default: 'Azure' or 'Local'.
    DefaultTarget       = 'Azure'

    # Machines used by the simulator and reports.
    Machines            = @('WELD-CELL-07', 'PRESS-12')

    # Azure resource identifiers used by the console's "Zarzadzanie Azure" menu
    # (provision / start / stop / destroy). These are the last-known names from the
    # live deployment and act only as a fallback: when a Terraform state is present
    # the console prefers `terraform output`, and a fresh `apply` mints a new random
    # suffix, so leaving these blank ('') is perfectly fine.
    AzureResourceGroup  = 'rg-factorytel-dev'
    AzureAppServiceName = 'app-factorytel-dev-hnzv6'
}
