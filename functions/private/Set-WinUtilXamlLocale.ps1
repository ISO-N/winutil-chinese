function Set-WinUtilXamlLocale {
    <#
        .SYNOPSIS
            Replaces the interface text in the parsed inputXML DOM with the loaded locale

        .DESCRIPTION
            Runs on the [xml] DOM of $inputXML after parsing and before XamlReader::Load,
            which reads this same DOM through XmlNodeReader - so xaml/inputXML.xaml keeps
            its upstream English text and nothing has to be serialized back.

            Attribute text is looked up by its exact source string. Elements whose mixed
            markup cannot be swapped attribute-by-attribute (the navigation buttons carry
            accelerator underlines) use a 'name:<Name>' key that replaces the whole content
            with plain text. TabItem headers are skipped on purpose: Invoke-WPFTab reads the
            header into $sync.currentTab and many code paths branch on that English value.
    #>
    param(
        [Parameter(Mandatory)]
        [System.Xml.XmlDocument]$Xaml
    )

    $table = $sync.L10n
    if (-not $table -or $table.Count -eq 0) {
        return
    }

    # @Name is in the list because the elements needing a whole-content 'name:' swap are
    # exactly the ones whose content is a property element and has no Content attribute.
    foreach ($node in $Xaml.SelectNodes("//*[@Content or @Text or @ToolTip or @Header or @Name]")) {
        if ($node.HasAttribute("Name") -and $table.ContainsKey("name:$($node.GetAttribute('Name'))")) {
            $translated = [string]$table["name:$($node.GetAttribute('Name'))"]

            if ($node.HasAttribute("Content")) {
                $node.SetAttribute("Content", $translated)
            } else {
                # Walk down to the element that owns the display text (e.g. the TextBlock
                # inside a navigation button) so its font and color settings survive. Only
                # elements whose content model accepts a text node may be rewritten: walking
                # into a Grid/StackPanel and setting InnerText there would delete the layout.
                $target = $node
                while ($true) {
                    $ownText = @($target.ChildNodes | Where-Object { $_.NodeType -eq "Text" -and $_.Value.Trim() })
                    $children = @($target.ChildNodes | Where-Object { $_.NodeType -eq "Element" })
                    if ($ownText.Count -gt 0 -or $children.Count -ne 1) {
                        break
                    }
                    $target = $children[0]
                }
                if ($target.LocalName -in @("TextBlock", "Run")) {
                    $target.InnerText = $translated
                }
            }
        }

        $isTabItem = $node.LocalName -eq "TabItem"
        foreach ($attributeName in @("Content", "Text", "ToolTip", "Header")) {
            if ($attributeName -eq "Header" -and $isTabItem) {
                continue
            }
            if (-not $node.HasAttribute($attributeName)) {
                continue
            }
            $source = $node.GetAttribute($attributeName)
            if (-not $source -or -not $table.ContainsKey($source)) {
                continue
            }
            $node.SetAttribute($attributeName, [string]$table[$source])
        }
    }

    # Inline text runs (TextBlocks mixing text with <LineBreak/> and friends) carry the
    # source indentation in the node value, so the lookup runs on the trimmed value and
    # only the inner text is swapped out.
    foreach ($textNode in $Xaml.SelectNodes("//text()")) {
        $value = $textNode.Value
        if (-not $value) {
            continue
        }
        $trimmed = $value.Trim()
        if (-not $trimmed -or -not $table.ContainsKey($trimmed)) {
            continue
        }
        $textNode.Value = $value.Replace($trimmed, [string]$table[$trimmed])
    }
}
