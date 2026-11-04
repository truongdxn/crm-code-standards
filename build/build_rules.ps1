<#
Validate rule files and build the merged rules section of README.md.
Runs on Windows PowerShell 5.1 (built into Windows 10/11) and PowerShell 7 (CI).

Usage:
    build\build_rules.cmd            # validate, then rewrite README.md
    build\build_rules.cmd --check    # validate, fail if README.md is stale (MR pipelines)

Keep this file ASCII-only: Windows PowerShell 5.1 reads BOM-less scripts as ANSI.
Non-ASCII output characters are built with [char] codes below.
#>
param([switch]$Check)

Set-StrictMode -Version 2.0
$ErrorActionPreference = 'Stop'

$Root      = Split-Path -Parent $PSScriptRoot
$RulesDir  = Join-Path $Root 'rules'
$Readme    = Join-Path $Root 'README.md'
$StartMark = '<!-- RULES:START -->'
$EndMark   = '<!-- RULES:END -->'
$Utf8      = New-Object System.Text.UTF8Encoding($false)   # UTF-8 without BOM
$Dash      = [string][char]0x2014                          # em dash
$Dot       = [string][char]0x00B7                          # middle dot

# Closed lists: only the standard owner changes these, via MR
$ScopeCodes      = @('GE', 'FE', 'BE')
$ScopeNames      = @{ GE = 'General'; FE = 'Frontend'; BE = 'Backend' }
$Severities      = @('Blocker', 'Major', 'Minor', 'Info')
$Statuses        = @('Draft', 'Active', 'Deprecated')
$RequiredFields  = @('id', 'title', 'severity', 'status', 'applied_to')
$RequiredSections = @('Description', 'Bad', 'Good')
$IdPattern       = '^(GE|FE|BE)-[0-9]{3}$'

function Read-Text([string]$Path) {
    # Normalize line endings so Windows checkouts and CI compare equal
    return [System.IO.File]::ReadAllText($Path, $Utf8).Replace("`r`n", "`n")
}

function Get-RelPath([string]$Path) {
    return $Path.Substring($Root.Length).TrimStart('\', '/').Replace('\', '/')
}

function Test-Empty($Value) {
    if ($null -eq $Value) { return $true }
    if ($Value -is [System.Collections.IList]) { return $Value.Count -eq 0 }
    return [string]::IsNullOrWhiteSpace([string]$Value)
}

function ConvertFrom-Scalar([string]$Text) {
    # Minimal YAML scalar: trim, then drop matching surrounding quotes
    $t = $Text.Trim()
    if ($t.Length -ge 2 -and (($t[0] -eq '"' -and $t[-1] -eq '"') -or ($t[0] -eq "'" -and $t[-1] -eq "'"))) {
        $t = $t.Substring(1, $t.Length - 2)
    }
    return $t
}

function Normalize-Key([string]$Key) {
    # Frontmatter keys are case/space tolerant: "Applied to" -> "applied_to", "ID" -> "id"
    return $Key.Trim().ToLowerInvariant().Replace(' ', '_')
}

function Split-FrontMatter([string]$Text) {
    <#
    Parse the YAML subset used by rule files:
        Key: value
        Key: [a, b, c]
        Key:
          - a
          - b
    Returns @{ Meta = hashtable; Content = string }. Throws on malformed frontmatter.
    #>
    $meta = @{}
    $m = [regex]::Match($Text, '\A\s*---[ \t]*\n(.*?)\n---[ \t]*(\n|\z)', 'Singleline')
    if (-not $m.Success) { return @{ Meta = $meta; Content = $Text } }

    $lastKey = $null
    $lineNo = 1
    foreach ($line in $m.Groups[1].Value.Split("`n")) {
        $lineNo++
        if ($line.Trim() -eq '' -or $line.TrimStart().StartsWith('#')) { continue }

        $item = [regex]::Match($line, '^\s*-\s+(.*)$')
        if ($item.Success -and $null -ne $lastKey) {
            # Block list item belonging to the previous key
            if (-not ($meta[$lastKey] -is [System.Collections.IList])) { $meta[$lastKey] = New-Object System.Collections.ArrayList }
            [void]$meta[$lastKey].Add((ConvertFrom-Scalar $item.Groups[1].Value))
            continue
        }

        $kv = [regex]::Match($line, '^([^:\s][^:]*):(?:\s+(.*))?$')
        if (-not $kv.Success) { throw "line ${lineNo}: cannot parse '$line'" }
        $key = Normalize-Key $kv.Groups[1].Value
        $raw = $kv.Groups[2].Value.Trim()

        if ($raw.StartsWith('[')) {
            if (-not $raw.EndsWith(']')) { throw "line ${lineNo}: unclosed list '$raw'" }
            $list = New-Object System.Collections.ArrayList
            foreach ($part in $raw.Substring(1, $raw.Length - 2).Split(',')) {
                if ($part.Trim() -ne '') { [void]$list.Add((ConvertFrom-Scalar $part)) }
            }
            $meta[$key] = $list
        } elseif ($raw -eq '') {
            $meta[$key] = $null   # may be filled by block list items
        } else {
            $meta[$key] = ConvertFrom-Scalar $raw
        }
        $lastKey = $key
    }
    return @{ Meta = $meta; Content = $Text.Substring($m.Length) }
}

function Test-Rule([string]$Path, [hashtable]$Meta, [string]$Content) {
    # Return a list of error strings for one rule file
    $rel = Get-RelPath $Path
    $errors = New-Object System.Collections.ArrayList

    $missing = @($RequiredFields | Where-Object { Test-Empty $Meta[$_] })
    if ($missing.Count -gt 0) {
        [void]$errors.Add("${rel}: missing frontmatter fields [$($missing -join ', ')]")
        return ,$errors
    }

    $rid = [string]$Meta['id']
    if ($rid -cnotmatch $IdPattern) {
        [void]$errors.Add("${rel}: invalid ID '$rid' (expected GE|FE|BE-NNN)")
    } else {
        $scope = $rid.Split('-')[0]
        if ([System.IO.Path]::GetFileNameWithoutExtension($Path) -cne $rid) {
            [void]$errors.Add("${rel}: file name must equal ID ($rid.md)")
        }
        if ((Split-Path -Leaf (Split-Path -Parent $Path)) -cne $scope) {
            [void]$errors.Add("${rel}: must be in folder rules/$scope/")
        }
    }

    if ($Severities -cnotcontains [string]$Meta['severity']) {
        [void]$errors.Add("${rel}: Severity '$($Meta['severity'])' not in [$($Severities -join ', ')]")
    }
    if ($Statuses -cnotcontains [string]$Meta['status']) {
        [void]$errors.Add("${rel}: Status '$($Meta['status'])' not in [$($Statuses -join ', ')]")
    }
    if (-not ($Meta['applied_to'] -is [System.Collections.IList])) {
        [void]$errors.Add("${rel}: 'Applied to' must be a list, e.g. [plugin, webjob]")
    }

    $sections = @([regex]::Matches($Content, '(?m)^##[ \t]+(.+?)[ \t]*$') | ForEach-Object { $_.Groups[1].Value })
    $missingSections = @($RequiredSections | Where-Object { $sections -cnotcontains $_ })
    if ($missingSections.Count -gt 0) {
        [void]$errors.Add("${rel}: missing sections [$($missingSections -join ', ')]")
    }
    return ,$errors
}

function Get-Rules {
    $rules  = New-Object System.Collections.ArrayList
    $errors = New-Object System.Collections.ArrayList
    $seen   = @{}

    # Ordinal sort so Windows and CI process files in the same order
    $files = [string[]]@(Get-ChildItem -Path $RulesDir -Filter '*.md' -Recurse -File | ForEach-Object { $_.FullName })
    [Array]::Sort($files, [StringComparer]::Ordinal)

    foreach ($path in $files) {
        if ([System.IO.Path]::GetFileName($path).StartsWith('_')) { continue }   # skip helper files such as _TEMPLATE.md
        $rel = Get-RelPath $path
        try {
            $post = Split-FrontMatter (Read-Text $path)
        } catch {
            [void]$errors.Add("${rel}: cannot parse frontmatter ($($_.Exception.Message))")
            continue
        }

        $meta = $post.Meta
        if (-not (Test-Empty $meta['id'])) { $meta['id'] = ([string]$meta['id']).Trim() }

        $fileErrors = Test-Rule $path $meta $post.Content
        if ($fileErrors.Count -gt 0) { [void]$errors.AddRange($fileErrors); continue }

        $rid = $meta['id']
        if ($seen.ContainsKey($rid)) {
            [void]$errors.Add("${rel}: duplicate ID $rid (already used by $($seen[$rid]))")
            continue
        }
        $seen[$rid] = $rel

        # Demote rule sections so they nest under the rule heading in README
        $meta['body']  = [regex]::Replace($post.Content.Trim(), '(?m)^## ', '#### ')
        $meta['scope'] = $rid.Split('-')[0]
        $meta['path']  = $rel
        [void]$rules.Add($meta)
    }

    # Cross-file check: replaced_by must point to an existing rule
    foreach ($r in $rules) {
        $target = $r['replaced_by']
        if (-not (Test-Empty $target) -and -not $seen.ContainsKey([string]$target)) {
            [void]$errors.Add("$($r['path']): 'Replaced by' points to unknown ID $target")
        }
    }

    $sorted = @($rules | Sort-Object -Property @{ Expression = { [array]::IndexOf($ScopeCodes, $_['scope']) } }, @{ Expression = { $_['id'] } })
    return @{ Rules = $sorted; Errors = $errors }
}

function Get-Anchor([string]$Heading) {
    # Heading anchor as generated by GitLab/GitHub: lowercase, drop punctuation, spaces -> hyphens
    return [regex]::Replace($Heading.ToLowerInvariant(), '[^\p{L}\p{N}\p{M}_ -]', '').Replace(' ', '-')
}

function Get-RuleHeading($Rule) {
    return "$($Rule['id']): $($Rule['title'])"
}

function Format-Rules([object[]]$Rules) {
    # Layout of the auto-generated part of README.md. Edit here to change the output.
    $active     = @($Rules | Where-Object { $_['status'] -ceq 'Active' })
    $drafts     = @($Rules | Where-Object { $_['status'] -ceq 'Draft' })
    $deprecated = @($Rules | Where-Object { $_['status'] -ceq 'Deprecated' })

    $o = New-Object System.Collections.Generic.List[string]
    $o.Add('_Auto-generated from `rules/` by `build/build_rules.ps1`. Do not edit this section by hand._')
    $o.Add('')
    $o.Add("**$($active.Count) active** $Dot $($drafts.Count) draft $Dot $($deprecated.Count) deprecated")
    $o.Add('')
    $o.Add('## Table of contents')
    $o.Add('')
    foreach ($code in $ScopeCodes) {
        $inScope = @($active | Where-Object { $_['scope'] -ceq $code })
        if ($inScope.Count -eq 0) { continue }
        $o.Add("- **$code $Dash $($ScopeNames[$code])**")
        foreach ($r in $inScope) {
            $o.Add("    - [$($r['id'])](#$(Get-Anchor (Get-RuleHeading $r))) $Dot $($r['title']) $Dot $($r['severity'])")
        }
    }
    if ($drafts.Count -gt 0)     { $o.Add('- [Draft rules](#draft-rules)') }
    if ($deprecated.Count -gt 0) { $o.Add('- [Deprecated rules](#deprecated-rules)') }
    $o.Add('')

    foreach ($code in $ScopeCodes) {
        $inScope = @($active | Where-Object { $_['scope'] -ceq $code })
        if ($inScope.Count -eq 0) { continue }
        $o.Add("## $code $Dash $($ScopeNames[$code])")
        $o.Add('')
        foreach ($r in $inScope) {
            $o.Add("### $(Get-RuleHeading $r)")
            $o.Add('')
            $o.Add("- **Severity:** $($r['severity'])")
            $o.Add("- **Applied to:** $(@($r['applied_to']) -join ', ')")
            $o.Add('')
            $o.Add($r['body'])
            $o.Add('')
        }
    }

    if ($drafts.Count -gt 0) {
        $o.Add('## Draft rules')
        $o.Add('')
        $o.Add('Trial period, non-blocking. Comment with `[Draft <ID>]` in reviews.')
        $o.Add('')
        $o.Add('| ID | Title | Severity |')
        $o.Add('| --- | --- | --- |')
        foreach ($r in $drafts) { $o.Add("| [$($r['id'])]($($r['path'])) | $($r['title']) | $($r['severity']) |") }
        $o.Add('')
    }

    if ($deprecated.Count -gt 0) {
        $o.Add('## Deprecated rules')
        $o.Add('')
        $o.Add('| ID | Title | Replaced by |')
        $o.Add('| --- | --- | --- |')
        foreach ($r in $deprecated) {
            $by = if (Test-Empty $r['replaced_by']) { '-' } else { $r['replaced_by'] }
            $o.Add("| [$($r['id'])]($($r['path'])) | $($r['title']) | $by |")
        }
    }

    # Collapse blank-line runs (also inside rule bodies) and trim
    return [regex]::Replace(($o -join "`n"), '\n{3,}', "`n`n").Trim()
}

function Invoke-Main {
    $result = Get-Rules
    if ($result.Errors.Count -gt 0) {
        Write-Host 'Rule validation failed:'
        foreach ($e in $result.Errors) { Write-Host "  - $e" }
        return 1
    }
    $rules = $result.Rules

    $text = Read-Text $Readme
    $s = $text.IndexOf($StartMark, [StringComparison]::Ordinal)
    $e = if ($s -ge 0) { $text.IndexOf($EndMark, $s + $StartMark.Length, [StringComparison]::Ordinal) } else { -1 }
    if ($s -lt 0 -or $e -lt 0) {
        Write-Host "README.md must contain both markers: $StartMark and $EndMark (in that order)"
        return 1
    }

    $head = $text.Substring(0, $s)
    $tail = $text.Substring($e + $EndMark.Length)
    $newText = "$head$StartMark`n$(Format-Rules $rules)`n$EndMark$tail"

    if ($Check) {
        if ($newText -cne $text) {
            Write-Host 'README.md is out of date. Run: build\build_rules.cmd'
            return 1
        }
        Write-Host "OK: $($rules.Count) rules valid, README.md up to date."
        return 0
    }

    # Always write UTF-8 (no BOM) + LF so Windows and CI produce identical output
    [System.IO.File]::WriteAllText($Readme, $newText, $Utf8)
    Write-Host "README.md rebuilt from $($rules.Count) rules."
    return 0
}

try { [Console]::OutputEncoding = $Utf8 } catch { }   # show Vietnamese titles correctly; ignore when no console
exit (Invoke-Main)
