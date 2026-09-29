function Resolve-WinUtilLocaleName {
    <#
        .SYNOPSIS
            Maps the -Language parameter or the system UI culture to a locale name to load

        .DESCRIPTION
            An explicit -Language wins. With 'auto' the exact UI culture name is returned and
            the caller matches it against the available locales, so adding a locale file later
            needs no change here.
    #>
    param(
        [string]$Language = "auto"
    )

    if ($Language -and $Language -ne "auto") {
        return $Language
    }

    try {
        $uiCulture = Get-UICulture
    } catch {
        return "en-US"
    }

    if (-not $uiCulture -or [string]::IsNullOrWhiteSpace($uiCulture.Name)) {
        return "en-US"
    }

    return $uiCulture.Name
}
