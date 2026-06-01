@{
    # Run all default rules, plus apply the deliberate exclusions below.
    IncludeDefaultRules = $true

    ExcludeRules = @(
        # Write-Host is intentional in these interactive CLI helper scripts: the coloured
        # console output IS the user-facing result, not log noise. (The library functions
        # that produce data return objects to the pipeline as normal.)
        'PSAvoidUsingWriteHost'
    )
}
