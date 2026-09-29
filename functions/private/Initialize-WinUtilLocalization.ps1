function Initialize-WinUtilLocalization {
    <#
        .SYNOPSIS
            Resolves the UI language and loads its strings into $sync.L10n

        .DESCRIPTION
            Locale catalogs are embedded as $WinUtilLocales by Compile.ps1. English is the
            source of truth everywhere else, so it loads an empty table and every lookup
            falls back to the source string. A missing or partial catalog degrades to
            English per string, never to an error.

            The table lives on $sync rather than in a $global: variable because only $sync
            is shared with the interface and worker runspaces.
    #>
    param(
        [string]$Language = "auto"
    )

    $sync.L10n = @{}
    $sync.L10nLanguage = "en-US"

    $requested = Resolve-WinUtilLocaleName -Language $Language
    $resolved = "en-US"

    if ((Test-Path variable:WinUtilLocales) -and $WinUtilLocales) {
        if ($WinUtilLocales.ContainsKey($requested)) {
            $resolved = $requested
        } elseif ($requested -like "*-*") {
            # Match the primary language tag, so a zh-TW system still finds zh-CN and a
            # future de-DE.json answers a de-AT system culture.
            $primaryPattern = $requested.Split("-")[0] + "-*"
            foreach ($available in $WinUtilLocales.Keys) {
                if ($available -like $primaryPattern) {
                    $resolved = $available
                    break
                }
            }
        }
    }

    if ($resolved -ne "en-US") {
        $table = @{}
        foreach ($property in $WinUtilLocales[$resolved].PSObject.Properties) {
            if ($property.Name -and $null -ne $property.Value) {
                $table[$property.Name] = [string]$property.Value
            }
        }
        $sync.L10n = $table
        $sync.L10nLanguage = $resolved
    }

    Write-WinUtilLog -Component "Localization" -Message "UI language '$resolved' (requested '$Language'), $($sync.L10n.Count) strings loaded."
}
