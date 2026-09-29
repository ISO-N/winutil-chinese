param (
    [switch]$Run
)

$OFS = "`r`n"

# Variable to sync between runspaces
$sync = [Hashtable]::Synchronized(@{})
$sync.configs = @{}

$script = (Get-Content -Path scripts\start.ps1) -replace '#{replaceme}', (Get-Date -Format 'yy.MM.dd')
$isLocalCompile = -not [string]::Equals($env:GITHUB_ACTIONS, "true", [StringComparison]::OrdinalIgnoreCase)
$script = $script -replace '#{islocalcompile}', $isLocalCompile.ToString().ToLowerInvariant()

$script += Get-ChildItem -Path functions -Recurse -File | ForEach-Object {
    Get-Content -Path $_.FullName -Raw
}

Get-ChildItem config | ForEach-Object {
    $obj = Get-Content -Path $_.FullName -Raw | ConvertFrom-Json

    if ($_.Name -eq "applications.json") {
        $fixed = [ordered]@{}
        foreach ($p in $obj.PSObject.Properties) {
            $fixed["WPFInstall$($p.Name)"] = $p.Value
        }
        $obj = [pscustomobject]$fixed
    }

    $json = $obj | ConvertTo-Json -Depth 10

    $sync.configs[$_.BaseName] = $obj
    $script += "`$sync.configs.$($_.BaseName) = @'`r`n$json`r`n'@ | ConvertFrom-Json"
}

# Locale catalogs are flat string-to-string tables keyed by the English source text. They are
# embedded like the configs because the compiled script has no locales/ folder to read from.
$script += '$WinUtilLocales = @{}'
Get-ChildItem locales -Filter *.json | ForEach-Object {
    $json = Get-Content -Path $_.FullName -Raw | ConvertFrom-Json | ConvertTo-Json -Depth 10
    $script += "`$WinUtilLocales['$($_.BaseName)'] = @'`r`n$json`r`n'@ | ConvertFrom-Json"
}

$xaml = Get-Content -Path xaml\inputXML.xaml -Raw
$script += "`$inputXML = @'`r`n$xaml`r`n'@"

$autounattendXml = Get-Content -Path tools\autounattend.xml -Raw
$script += "`$WinUtilAutounattendXml = @'`r`n$autounattendXml`r`n'@"

$script += Get-Content -Path scripts\main.ps1 -Raw

# UTF-8 with BOM: locale here-strings carry non-ASCII text and without a BOM Windows
# PowerShell 5.1 would read the generated script in the system ANSI code page. The BOM is
# correct for running .\winutil.ps1 from disk, but it breaks `irm ... | iex` because the
# download leaves U+FEFF as the first character of the string, so the publish workflow
# uploads a BOM-less copy of this file as the release asset.
[System.IO.File]::WriteAllText("winutil.ps1", $script -join "`r`n", [System.Text.UTF8Encoding]::new($true))

if ($Run) {
    .\Winutil.ps1
}
