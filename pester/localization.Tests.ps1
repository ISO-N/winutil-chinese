#===========================================================================
# Tests - Localization
#===========================================================================

BeforeAll {
    $script:repoRoot = (Resolve-Path (Join-Path $PSScriptRoot "..")).Path
    . (Join-Path $script:repoRoot "functions\private\Resolve-WinUtilLocaleName.ps1")
    . (Join-Path $script:repoRoot "functions\private\Initialize-WinUtilLocalization.ps1")
    . (Join-Path $script:repoRoot "functions\private\Get-WinUtilLocalizedText.ps1")
    . (Join-Path $script:repoRoot "functions\private\Set-WinUtilXamlLocale.ps1")

    # The loader logs what it resolved; keep the test output free of log plumbing
    function Write-WinUtilLog { }

    $script:sync = [Hashtable]::Synchronized(@{})
    $sync = $script:sync

    $script:localeDir = Join-Path $script:repoRoot "locales"

    # The catalog JSON, shared by every fixture below
    $script:zhJson = @'
{
  "Run Tweaks": "\u8fd0\u884c Tweaks",
  "A tooltip": "\u4e00\u4e2a\u63d0\u793a",
  "Selected Apps: {0}": "\u5df2\u9009\u5e94\u7528\uff1a{0}",
  "name:WPFTab1BT": "\u5b89\u88c5",
  "Status": "\u72b6\u6001",
  "Hover for info": "\u60ac\u505c\u67e5\u770b\u4fe1\u606f"
}
'@

    # Production shape for the loader: the embedded entry is a PSCustomObject from
    # ConvertFrom-Json and the loader reads it through PSObject.Properties.
    $script:zhCatalogObject = ConvertFrom-Json $script:zhJson

    # Runtime shape for readers: the loader always converts that object into a plain
    # hashtable before anything looks keys up.
    $script:zhCatalog = @{}
    foreach ($property in $script:zhCatalogObject.PSObject.Properties) {
        $script:zhCatalog[$property.Name] = [string]$property.Value
    }
}

#===========================================================================
# Locale catalog files
#===========================================================================

Describe "Locale catalog files" {
    BeforeAll {
        $script:enCatalog = Get-Content (Join-Path $script:localeDir "en-US.json") -Raw | ConvertFrom-Json
        $script:zhCatalogFile = Get-Content (Join-Path $script:localeDir "zh-CN.json") -Raw | ConvertFrom-Json
        $script:enKeys = @($script:enCatalog.PSObject.Properties.Name)
        $script:zhKeys = @($script:zhCatalogFile.PSObject.Properties.Name)
    }

    It "en-US.json parses to a non-empty flat catalog" {
        $script:enKeys.Count | Should -BeGreaterThan 0
        foreach ($key in $script:enKeys) {
            $script:enCatalog.$key | Should -BeOfType [string]
        }
    }

    It "zh-CN.json keys are all known to en-US.json" {
        foreach ($key in $script:zhKeys) {
            $script:enKeys | Should -Contain $key
        }
    }

    It "zh-CN.json has no empty translations" {
        foreach ($key in $script:zhKeys) {
            $script:zhCatalogFile.$key | Should -Not -BeNullOrEmpty
        }
    }
}

#===========================================================================
# Resolve-WinUtilLocaleName
#===========================================================================

Describe "Resolve-WinUtilLocaleName" {
    It "returns an explicit language unchanged" {
        Resolve-WinUtilLocaleName -Language "zh-CN" | Should -Be "zh-CN"
        Resolve-WinUtilLocaleName -Language "en-US" | Should -Be "en-US"
    }

    It "resolves auto to the exact UI culture name" {
        Mock Get-UICulture { [pscustomobject]@{ Name = "de-DE" } }
        Resolve-WinUtilLocaleName -Language "auto" | Should -Be "de-DE"
    }

    It "resolves auto to en-US when the culture is unavailable" {
        Mock Get-UICulture { throw "no culture" }
        Resolve-WinUtilLocaleName -Language "auto" | Should -Be "en-US"
    }

    It "resolves auto to en-US when the culture name is empty" {
        Mock Get-UICulture { [pscustomobject]@{ Name = "" } }
        Resolve-WinUtilLocaleName -Language "auto" | Should -Be "en-US"
    }
}

#===========================================================================
# Initialize-WinUtilLocalization
#===========================================================================

Describe "Initialize-WinUtilLocalization" {
    BeforeAll {
        $script:fixtures = @{
            "zh-CN" = $script:zhCatalogObject
            "en-US" = ConvertFrom-Json '{}'
        }
    }

    BeforeEach {
        $script:sync.L10n = $null
        $script:sync.L10nLanguage = $null
        $WinUtilLocales = $script:fixtures
    }

    It "loads the requested catalog into sync state as strings" {
        Initialize-WinUtilLocalization -Language "zh-CN"

        $sync.L10nLanguage | Should -Be "zh-CN"
        $sync.L10n["Run Tweaks"] | Should -Be ([char]0x8FD0 + [char]0x884C + " Tweaks")
        $sync.L10n["name:WPFTab1BT"] | Should -Not -BeNullOrEmpty
    }

    It "keeps an empty table for en-US" {
        Initialize-WinUtilLocalization -Language "en-US"

        $sync.L10nLanguage | Should -Be "en-US"
        $sync.L10n.Count | Should -Be 0
    }

    It "matches the primary language tag when the exact locale is unavailable" {
        Mock Get-UICulture { [pscustomobject]@{ Name = "zh-TW" } }
        Initialize-WinUtilLocalization -Language "auto"

        $sync.L10nLanguage | Should -Be "zh-CN"
    }

    It "degrades an unknown auto culture to English" {
        Mock Get-UICulture { [pscustomobject]@{ Name = "de-DE" } }
        Initialize-WinUtilLocalization -Language "auto"

        $sync.L10nLanguage | Should -Be "en-US"
        $sync.L10n.Count | Should -Be 0
    }

    It "degrades to English when the requested locale file is missing" {
        Initialize-WinUtilLocalization -Language "fr-FR"

        $sync.L10nLanguage | Should -Be "en-US"
        $sync.L10n.Count | Should -Be 0
    }

    It "survives a missing WinUtilLocales table" {
        Remove-Item variable:WinUtilLocales -ErrorAction SilentlyContinue
        Initialize-WinUtilLocalization -Language "zh-CN"

        $sync.L10nLanguage | Should -Be "en-US"
        $sync.L10n.Count | Should -Be 0
    }
}

#===========================================================================
# Get-WinUtilLocalizedText
#===========================================================================

Describe "Get-WinUtilLocalizedText" {
    BeforeEach {
        $script:sync.L10n = $script:zhCatalog
    }

    It "returns the source string when no table is loaded" {
        $script:sync.L10n = $null
        Get-WinUtilLocalizedText "Run Tweaks" | Should -Be "Run Tweaks"
    }

    It "returns the source string when the table is empty" {
        $script:sync.L10n = @{}
        Get-WinUtilLocalizedText "Run Tweaks" | Should -Be "Run Tweaks"
    }

    It "returns the translation on a hit" {
        Get-WinUtilLocalizedText "Run Tweaks" | Should -Not -Be "Run Tweaks"
    }

    It "returns the source string on a miss" {
        Get-WinUtilLocalizedText "Not In The Catalog" | Should -Be "Not In The Catalog"
    }

    It "formats template keys with values" {
        Get-WinUtilLocalizedText "Selected Apps: {0}" -Values 3 | Should -Match "3$"
    }

    It "passes empty strings through" {
        Get-WinUtilLocalizedText "" | Should -Be ""
    }

    It "resolves name: overrides like any other key" {
        Get-WinUtilLocalizedText "name:WPFTab1BT" | Should -Not -BeNullOrEmpty
    }
}

#===========================================================================
# Set-WinUtilXamlLocale
#===========================================================================

Describe "Set-WinUtilXamlLocale" {
    BeforeAll {
        $script:xamlTemplate = @'
<Window
        xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation"
        xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml">
    <TabItem Header="Install"/>
    <Button Name="TestNamedButton" Content="Run Tweaks" ToolTip="A tooltip"/>
    <TextBlock>
        Hover for info
    </TextBlock>
    <ToggleButton Name="WPFTab1BT">
        <ToggleButton.Content>
            <TextBlock FontSize="12"><Underline>I</Underline>nstall</TextBlock>
        </ToggleButton.Content>
    </ToggleButton>
    <TextBlock Name="TestInlineNote" Text="Status"/>
    <Button Content="&#xE921;"/>
</Window>
'@
    }

    BeforeEach {
        [xml]$script:doc = $script:xamlTemplate
        $script:sync.L10n = $script:zhCatalog
    }

    It "is a no-op when no locale is loaded" {
        $script:sync.L10n = @{}
        Set-WinUtilXamlLocale -Xaml $script:doc

        $script:doc.SelectSingleNode("//*[local-name()='Button' and @Name='TestNamedButton']").GetAttribute("Content") | Should -Be "Run Tweaks"
    }

    It "leaves TabItem headers alone because they are logic keys" {
        Set-WinUtilXamlLocale -Xaml $script:doc

        $script:doc.SelectSingleNode("//*[local-name()='TabItem']").GetAttribute("Header") | Should -Be "Install"
    }

    It "translates attributes by exact source string" {
        Set-WinUtilXamlLocale -Xaml $script:doc

        $button = $script:doc.SelectSingleNode("//*[local-name()='Button' and @Name='TestNamedButton']")
        $button.GetAttribute("Content") | Should -Not -Be "Run Tweaks"
        $button.GetAttribute("ToolTip") | Should -Not -Be "A tooltip"
    }

    It "replaces the whole content of a name: element and keeps its inner styling element" {
        Set-WinUtilXamlLocale -Xaml $script:doc

        $toggle = $script:doc.SelectSingleNode("//*[local-name()='ToggleButton' and @Name='WPFTab1BT']")
        $inner = $toggle.SelectNodes(".//*[local-name()='TextBlock']")
        $inner.Count | Should -Be 1
        $inner[0].GetAttribute("FontSize") | Should -Be "12"
        ($inner[0].SelectNodes(".//*[local-name()='Underline']")).Count | Should -Be 0
        @($inner[0].SelectNodes("./text()"))[0].Value | Should -Not -BeNullOrEmpty
    }

    It "translates Text attributes" {
        Set-WinUtilXamlLocale -Xaml $script:doc

        $script:doc.SelectSingleNode("//*[local-name()='TextBlock' and @Name='TestInlineNote']").GetAttribute("Text") | Should -Not -Be "Status"
    }

    It "translates inline text runs and preserves their surrounding whitespace" {
        Set-WinUtilXamlLocale -Xaml $script:doc

        $inline = $script:doc.SelectSingleNode("//*[local-name()='TextBlock' and not(@Name)]")
        $textNode = @($inline.SelectNodes("./text()"))[0]
        $textNode.Value | Should -Match "^[\s\r\n]+"
        $textNode.Value.Trim() | Should -Not -Be "Hover for info"
    }

    It "leaves icon glyphs and unknown strings untouched" {
        Set-WinUtilXamlLocale -Xaml $script:doc

        $glyph = $script:doc.SelectSingleNode("//*[local-name()='Button' and not(@Name)]")
        $glyph.GetAttribute("Content") | Should -Be ([string][char]0xE921)
    }
}
