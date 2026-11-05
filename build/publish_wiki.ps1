<#
Publish the generated "All rules" page and the contribution guide to the project wiki.
Only these two pages are managed by CI; other wiki pages (e.g. home) are left untouched.
Requires git on PATH. ASCII-only for Windows PowerShell 5.1.

Usage:
    powershell -NoProfile -File build/publish_wiki.ps1 [-Page dist/All-rules.md]

Required env:
    WIKI_URL  git URL of the wiki repo (with credentials in CI)
#>
param([string]$Page = 'dist/All-rules.md')

Set-StrictMode -Version 2.0
$ErrorActionPreference = 'Stop'

$Root = Split-Path -Parent $PSScriptRoot
$Utf8 = New-Object System.Text.UTF8Encoding($false)

function Invoke-Git {
    # Run git and stop on a non-zero exit code (native commands do not throw on their own)
    & git -c core.autocrlf=false @args
    if ($LASTEXITCODE -ne 0) { throw "git $($args -join ' ') failed with exit code $LASTEXITCODE" }
}

function Copy-Page([string]$Source, [string]$Target) {
    # Copy as UTF-8 without BOM + LF, whatever the checkout line endings are
    $text = [System.IO.File]::ReadAllText($Source, $Utf8).Replace("`r`n", "`n")
    [System.IO.File]::WriteAllText($Target, $text, $Utf8)
}

if (-not $env:WIKI_URL) { Write-Host 'WIKI_URL is required.'; exit 1 }
$pagePath = if ([System.IO.Path]::IsPathRooted($Page)) { $Page } else { Join-Path (Get-Location) $Page }
if (-not (Test-Path $pagePath)) { Write-Host "Missing ${Page}: run build/build_rules.ps1 -Out first."; exit 1 }

$work = Join-Path ([System.IO.Path]::GetTempPath()) ("wiki-" + [guid]::NewGuid().ToString('N'))
try {
    & git clone -q --depth 1 $env:WIKI_URL $work
    if ($LASTEXITCODE -ne 0) {
        Write-Host 'Cannot clone the wiki. Create its first page in the GitLab UI and check WIKI_TOKEN.'
        exit 1
    }
    Push-Location $work
    try {
        Copy-Page $pagePath (Join-Path $work 'All-rules.md')
        Copy-Page (Join-Path $Root 'CONTRIBUTING.md') (Join-Path $work 'Contributing.md')

        Invoke-Git add All-rules.md Contributing.md
        & git diff --cached --quiet
        if ($LASTEXITCODE -eq 0) { Write-Host 'Wiki already up to date.'; exit 0 }

        $sha = if ($env:CI_COMMIT_SHORT_SHA) { $env:CI_COMMIT_SHORT_SHA } else { (& git -C $Root rev-parse --short HEAD) }
        $project = if ($env:CI_PROJECT_PATH) { $env:CI_PROJECT_PATH } else { 'local' }
        Invoke-Git -c user.name="CI Wiki Bot" -c user.email="ci-wiki-bot@noreply" commit -q -m "Sync from $project@$sha"
        Invoke-Git push -q origin HEAD
        Write-Host 'Wiki updated:'
        & git show --stat --format="  %s" HEAD
    } finally {
        Pop-Location
    }
} finally {
    if (Test-Path $work) { Remove-Item -Recurse -Force $work }
}
exit 0
