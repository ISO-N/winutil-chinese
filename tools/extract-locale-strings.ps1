<#
.SYNOPSIS
    Extracts every translatable source string and maintains locales/en-US.json

.DESCRIPTION
    The locale catalogs are keyed by the exact English source text, so en-US.json doubles as
    the canonical key catalog: identity mapping, regenerated from source on every run.

    Surfaces scanned:
      - xaml/inputXML.xaml: Content/Text/ToolTip attributes, non-TabItem Header attributes,
        inline text nodes, and "name:<Name>" keys for elements whose mixed markup (accelerator
        underlines) needs a whole-content swap.
      - config/*.json: the display fields (Content/Description/category/ComboItems/
        ComboDescriptions); machine fields are ignored.
      - functions/ and scripts/: literal arguments of Get-WinUtilLocalizedText plus the static
        -Message/-Title literals of Show-WinUtilMessage and Show-CustomDialog.

    TabItem headers are deliberately absent: they are logic keys (see Set-WinUtilXamlLocale).

.PARAMETER Check
    Report drift without writing en-US.json. Exits 1 when zh-CN.json is out of sync.

.EXAMPLE
    pwsh tools/extract-locale-strings.ps1
#>
param(
    [switch]$Check
)

$ErrorActionPreference = "Stop"

$repoRoot = Split-Path -Parent $PSScriptRoot
$strings = [System.Collections.Generic.SortedSet[string]]::new([System.StringComparer]::Ordinal)
$nameOverrides = @{} # name:<control> -> English plain text

#===========================================================================
# XAML
#===========================================================================

[xml]$xamlDoc = Get-Content -Path (Join-Path $repoRoot "xaml\inputXML.xaml") -Raw

foreach ($node in $xamlDoc.SelectNodes("//*")) {
    foreach ($attributeName in @("Content", "Text", "ToolTip", "Header")) {
        if ($attributeName -eq "Header" -and $node.LocalName -eq "TabItem") { continue }
        if (-not $node.HasAttribute($attributeName)) { continue }
        $value = $node.GetAttribute($attributeName)
        # Markup extensions like {Binding} are not display text
        if ($value.Trim().StartsWith("{")) { continue }
        if ($value.Trim() -match "[A-Za-z]" -and $value.Trim() -notmatch "^[A-Za-z]$") { [void]$strings.Add($value) }
    }

    if ($node.HasAttribute("Name")) {
        # Mirror Set-WinUtilXamlLocale's walk to the element that owns the display text, so a
        # mixed-markup control (navigation button with <Underline>) gets a whole-content key.
        # Only text-safe leaves qualify: containers (Grid/StackPanel/TabItem) must keep their
        # layout children, and their inner text is picked up run-by-run by the text-node pass.
        $target = $node
        while ($true) {
            $ownText = @($target.ChildNodes | Where-Object { $_.NodeType -eq "Text" -and $_.Value.Trim() })
            $children = @($target.ChildNodes | Where-Object { $_.NodeType -eq "Element" })
            if ($ownText.Count -gt 0 -or $children.Count -ne 1) { break }
            $target = $children[0]
        }
        if ($target -ne $node -and $target.LocalName -in @("TextBlock", "Run")) {
            $plain = $target.InnerText.Trim()
            if ($plain -match "[A-Za-z]") {
                $nameOverrides["name:$($node.GetAttribute('Name'))"] = $plain
            }
        }
    }
}

foreach ($textNode in $xamlDoc.SelectNodes("//text()")) {
    $trimmed = $textNode.Value.Trim()
    if (-not $trimmed -or $trimmed -notmatch "[A-Za-z]" -or $trimmed -match "^[A-Za-z]$") { continue }

    # Text inside an element that a name: key replaces wholesale is not individually
    # translatable - the runtime swaps that whole content before any per-run lookup.
    $covered = $false
    $owner = $textNode.ParentNode
    while ($owner) {
        if ($owner.NodeType -eq "Element" -and $owner.HasAttribute("Name") -and
            $nameOverrides.ContainsKey("name:$($owner.GetAttribute('Name'))")) {
            $covered = $true
            break
        }
        $owner = $owner.ParentNode
    }
    if (-not $covered) { [void]$strings.Add($trimmed) }
}

#===========================================================================
# Config JSONs
#===========================================================================

$displayFields = @("Content", "Description", "description", "category", "Category")

Get-ChildItem -Path (Join-Path $repoRoot "config") -Filter *.json | ForEach-Object {
    $config = Get-Content -Path $_.FullName -Raw | ConvertFrom-Json
    foreach ($entry in $config.PSObject.Properties) {
        foreach ($field in $entry.Value.PSObject.Properties) {
            if ($displayFields -contains $field.Name -and $field.Value -is [string]) {
                $value = $field.Value
                if ($field.Name -in "category", "Category") {
                    # The renderer displays the category with its "__" ordering prefix stripped
                    $value = $value -replace ".*__", ""
                }
                if ($value.Trim() -match "[A-Za-z]") { [void]$strings.Add($value) }
            }
            if ($field.Name -eq "ComboItems" -and $field.Value -is [string]) {
                # Mirror the renderer: pipe-delimited when present, space-delimited otherwise
                $separator = if ($field.Value.Contains("|")) { "\|" } else { " " }
                foreach ($item in ($field.Value -split $separator)) {
                    if ($item.Trim() -match "[A-Za-z]") { [void]$strings.Add($item) }
                }
            }
            if ($field.Name -eq "ComboDescriptions" -and $field.Value) {
                foreach ($item in $field.Value.PSObject.Properties) {
                    if ($item.Value -is [string] -and $item.Value.Trim() -match "[A-Za-z]") {
                        [void]$strings.Add($item.Value)
                    }
                }
            }
        }
    }
}

#===========================================================================
# PowerShell call sites (AST, so escapes like `n are resolved exactly as at runtime)
#===========================================================================

function Get-WinUtilLiteralValue {
    param($Expression)

    if ($Expression -is [System.Management.Automation.Language.StringConstantExpressionAst]) {
        return $Expression.Value
    }
    # A here-string or expandable string without any $substitution is constant text
    if ($Expression -is [System.Management.Automation.Language.ExpandableStringExpressionAst] -and
        $Expression.NestedExpressions.Count -eq 0) {
        return $Expression.FormatString
    }
    if ($Expression -is [System.Management.Automation.Language.ParenExpressionAst]) {
        return Get-WinUtilLiteralValue -Expression $Expression.Expression
    }
    return $null
}

function Add-WinUtilCommandLiterals {
    param($CommandAst, [string[]]$ParameterNames, [int[]]$PositionalIndexes)

    $elements = $CommandAst.CommandElements
    foreach ($index in $PositionalIndexes) {
        if ($index -lt $elements.Count) {
            $literal = Get-WinUtilLiteralValue -Expression $elements[$index]
            if ($literal) { [void]$strings.Add($literal) }
        }
    }

    for ($i = 1; $i -lt $elements.Count; $i++) {
        $parameter = $elements[$i]
        if ($parameter -isnot [System.Management.Automation.Language.CommandParameterAst]) { continue }
        if ($ParameterNames -notcontains $parameter.ParameterName) { continue }
        if ($i + 1 -ge $elements.Count) { continue }
        $literal = Get-WinUtilLiteralValue -Expression $elements[$i + 1]
        if ($literal) { [void]$strings.Add($literal) }
    }
}

Get-ChildItem -Path @((Join-Path $repoRoot "functions"), (Join-Path $repoRoot "scripts")) -Filter *.ps1 -Recurse | ForEach-Object {
    $ast = [System.Management.Automation.Language.Parser]::ParseFile($_.FullName, [ref]$null, [ref]$null)
    $commands = $ast.FindAll({ $args[0] -is [System.Management.Automation.Language.CommandAst] }, $true)

    foreach ($command in $commands) {
        switch ($command.GetCommandName()) {
            "Get-WinUtilLocalizedText" {
                Add-WinUtilCommandLiterals -CommandAst $command -ParameterNames @("Text") -PositionalIndexes @(1)
            }
            { $_ -in "Show-WinUtilMessage", "Show-CustomDialog" } {
                Add-WinUtilCommandLiterals -CommandAst $command -ParameterNames @("Message", "Title") -PositionalIndexes @()
            }
        }
    }
}

#===========================================================================
# Output
#===========================================================================

$catalog = [ordered]@{}
foreach ($key in $strings) { $catalog[$key] = $key }
foreach ($name in $nameOverrides.Keys) { $catalog[$name] = $nameOverrides[$name] }

$enPath = Join-Path $repoRoot "locales\en-US.json"
$zhPath = Join-Path $repoRoot "locales\zh-CN.json"

$zhKeys = @()
if (Test-Path $zhPath) {
    $zhCatalog = Get-Content -Path $zhPath -Raw | ConvertFrom-Json
    if ($zhCatalog) {
        # Per-property .Name: asking the collection for .Name on an empty object yields @($null)
        $zhKeys = @($zhCatalog.PSObject.Properties | ForEach-Object { $_.Name })
    }
}

$stale = @($zhKeys | Where-Object { -not $catalog.Contains($_) })
$untranslated = @($catalog.Keys | Where-Object { $zhKeys -notcontains $_ })

Write-Host "en-US catalog: $($catalog.Count) keys"
Write-Host "zh-CN: $($zhKeys.Count) keys, $($untranslated.Count) untranslated, $($stale.Count) stale"

if ($stale.Count -gt 0) {
    Write-Host "Keys in zh-CN.json no longer present in source:" -ForegroundColor Yellow
    $stale | ForEach-Object { Write-Host "  - $_" -ForegroundColor Yellow }
}

if ($Check) {
    if ($stale.Count -gt 0 -or $untranslated.Count -gt 0) { exit 1 }
    exit 0
}

$json = $catalog | ConvertTo-Json
# UTF-8 with BOM so Windows PowerShell 5.1 reads the file as UTF-8 rather than ANSI
[System.IO.File]::WriteAllText($enPath, $json, [System.Text.UTF8Encoding]::new($true))
Write-Host "Wrote $enPath"
