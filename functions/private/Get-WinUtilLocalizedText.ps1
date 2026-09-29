function Get-WinUtilLocalizedText {
    <#
        .SYNOPSIS
            Returns the loaded translation for an English source string, or the source itself

        .DESCRIPTION
            Locale catalogs are keyed by the exact English source text, so an untranslated
            string degrades to English by missing the lookup instead of raising an error.
            Source text with interpolated values is keyed as a '{0}' template and filled in
            here with -Values.
    #>
    param(
        [Parameter(Position = 0)]
        [AllowEmptyString()]
        [string]$Text,

        [object[]]$Values
    )

    if (-not $Text) {
        return $Text
    }

    # Template formatting applies to the source string too: an untranslated '{0}' key still
    # has to produce the same interpolated text the old inline code built.
    $translated = $Text
    $table = $sync.L10n
    if ($table -and $table.ContainsKey($Text)) {
        $translated = [string]$table[$Text]
    }
    # Format whenever -Values was passed, not when the values are truthy: a '{0}' filled
    # with 0 or an empty string must still interpolate.
    if ($PSBoundParameters.ContainsKey("Values")) {
        $translated = [string]::Format($translated, $Values)
    }
    return $translated
}
