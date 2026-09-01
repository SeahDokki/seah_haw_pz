<#
.SYNOPSIS
    Stages the H:AW mod into the Project Zomboid Workshop folder for upload.

.DESCRIPTION
    Builds %USERPROFILE%\Zomboid\Workshop\<ItemName>\ in the layout the in-game
    Workshop uploader expects:

        <ItemName>\
            workshop.txt          metadata: title, description, tags, id
            preview.png           256x256 thumbnail
            Contents\
                mods\
                    SHAW\     the mod itself

    Only Contents\mods\<ModId> is wiped and rewritten, so files deleted or
    renamed in the repo do not linger in the staged copy.

    workshop.txt is NEVER overwritten once it exists. After the first upload the
    game writes the Steam item id into it, and replacing that file would make
    the next upload publish a second item instead of updating the first. Edit
    the title, description and tags in the staged file, not here - or pass
    -RefreshMetadata to rewrite everything except the id.

    Local dev script - not tracked by git.

.PARAMETER ModId
    Folder name under Contents\mods. Must match the mod.info id.

.PARAMETER ItemName
    Folder name under Zomboid\Workshop. This is the staging folder the uploader
    lists, not the published title (that comes from workshop.txt).

.PARAMETER ZomboidPath
    The Zomboid user folder. Override if yours is not under %USERPROFILE%.

.PARAMETER RefreshMetadata
    Rewrite workshop.txt from mod.info, preserving any existing id= line.

.PARAMETER DryRun
    Print what would happen without touching anything.

.EXAMPLE
    .\build.ps1
    .\build.ps1 -DryRun
    .\build.ps1 -RefreshMetadata
#>

[CmdletBinding()]
param(
    [string]$ModId = 'SHAW',
    [string]$ItemName = 'SHAW',
    [string]$ZomboidPath = (Join-Path $env:USERPROFILE 'Zomboid'),
    [switch]$RefreshMetadata,
    [switch]$DryRun
)

$ErrorActionPreference = 'Stop'

# ---------------------------------------------------------------- resolve --

$sourcePath = Join-Path $PSScriptRoot $ModId

if (-not (Test-Path -LiteralPath $sourcePath)) {
    throw "Source folder not found: $sourcePath"
}

$modInfo = Join-Path $sourcePath 'mod.info'
if (-not (Test-Path -LiteralPath $modInfo)) {
    throw "No mod.info in $sourcePath - is this the right folder?"
}

$workshopRoot = Join-Path $ZomboidPath 'Workshop'
if (-not (Test-Path -LiteralPath $workshopRoot)) {
    throw "Workshop folder not found: $workshopRoot`nStart the game once, or pass -ZomboidPath."
}

# Safety check: everything we write must sit inside Zomboid\Workshop.
$resolvedWorkshopRoot = (Resolve-Path -LiteralPath $workshopRoot).ProviderPath.TrimEnd('\')
$itemPath = Join-Path $resolvedWorkshopRoot $ItemName

if ($itemPath -eq $resolvedWorkshopRoot -or
    -not $itemPath.StartsWith($resolvedWorkshopRoot + '\', [StringComparison]::OrdinalIgnoreCase)) {
    throw "Refusing to operate on '$itemPath' - it is not inside '$resolvedWorkshopRoot'."
}

$contentsPath = Join-Path $itemPath 'Contents'
$modsPath = Join-Path $contentsPath 'mods'
$stagedMod = Join-Path $modsPath $ModId
$workshopTxt = Join-Path $itemPath 'workshop.txt'
$previewDest = Join-Path $itemPath 'preview.png'

Write-Host ''
Write-Host "  Source      : $sourcePath"
Write-Host "  Workshop    : $itemPath"
if ($DryRun) { Write-Host '  Mode        : DRY RUN (nothing will be written)' -ForegroundColor Yellow }
Write-Host ''

# ------------------------------------------------------------ read mod.info --

# Read the fields workshop.txt wants, so the two cannot drift apart.
$info = @{}
foreach ($line in Get-Content -LiteralPath $modInfo) {
    if ($line -match '^\s*([^=#]+?)\s*=\s*(.*)$') {
        $info[$Matches[1]] = $Matches[2]
    }
}

foreach ($field in @('name', 'id', 'description')) {
    if (-not $info.ContainsKey($field)) {
        throw "mod.info has no '$field=' line."
    }
}

if ($info['id'] -ne $ModId) {
    throw "mod.info id is '$($info['id'])' but staging as '$ModId' - these must match."
}

# --------------------------------------------------------------- structure --

foreach ($dir in @($itemPath, $contentsPath, $modsPath)) {
    if (-not (Test-Path -LiteralPath $dir)) {
        Write-Host "  Creating $dir" -ForegroundColor DarkGray
        if (-not $DryRun) { New-Item -ItemType Directory -Path $dir -Force | Out-Null }
    }
}

# ------------------------------------------------------------------- clean --

if (Test-Path -LiteralPath $stagedMod) {
    $existing = @(Get-ChildItem -LiteralPath $stagedMod -Force -Recurse -File)
    Write-Host "  Clearing $($existing.Count) staged file(s)..." -ForegroundColor DarkGray
    if (-not $DryRun) {
        Get-ChildItem -LiteralPath $stagedMod -Force | Remove-Item -Recurse -Force -Confirm:$false
    }
}
else {
    if (-not $DryRun) { New-Item -ItemType Directory -Path $stagedMod -Force | Out-Null }
}

# -------------------------------------------------------------------- copy --

$sourceFiles = @(Get-ChildItem -LiteralPath $sourcePath -Force -Recurse -File)

if (-not $DryRun) {
    Copy-Item -Path (Join-Path $sourcePath '*') -Destination $stagedMod -Recurse -Force
}

Write-Host "  Copied $($sourceFiles.Count) file(s) into Contents\mods\$ModId." -ForegroundColor Green

# ----------------------------------------------------------------- preview --

# The uploader wants a 256x256 preview.png beside workshop.txt. The mod ships
# one; reuse it rather than keeping a second copy in sync by hand.
$previewSource = Join-Path $sourcePath 'preview.png'

if (Test-Path -LiteralPath $previewSource) {
    if (-not $DryRun) { Copy-Item -LiteralPath $previewSource -Destination $previewDest -Force }
    Write-Host '  preview.png copied.' -ForegroundColor Green
}
elseif (-not (Test-Path -LiteralPath $previewDest)) {
    Write-Warning "No preview.png in $sourcePath and none staged - Steam will show a blank thumbnail."
}

# ------------------------------------------------------------ workshop.txt --

$existingId = $null
$kept = [ordered]@{}
$hasWorkshopTxt = Test-Path -LiteralPath $workshopTxt

if ($hasWorkshopTxt) {
    # Everything here is owned by the published item, not by this repo:
    #
    #   id          written by the game on first upload. Losing it makes the
    #               next upload publish a duplicate instead of updating.
    #   title/tags  edited on the Workshop page or in this file, and not
    #               derivable from mod.info - `name=` is the in-game mod name,
    #               which is deliberately shorter than the store title.
    #   visibility  a deliberate choice, and defaulting it back to public could
    #               expose an item someone had unlisted.
    #
    # So -RefreshMetadata rewrites the description and nothing else.
    foreach ($key in @('id', 'title', 'tags', 'visibility')) {
        $line = Select-String -LiteralPath $workshopTxt -Pattern "^\s*$key\s*=\s*(.+)$" |
            Select-Object -First 1
        if ($line) { $kept[$key] = $line.Matches[0].Groups[1].Value.Trim() }
    }
    if ($kept.Contains('id')) { $existingId = $kept['id'] }
}

if ($hasWorkshopTxt -and -not $RefreshMetadata) {
    if ($existingId) {
        Write-Host "  workshop.txt kept (published item id=$existingId)." -ForegroundColor DarkGray
    }
    else {
        Write-Host '  workshop.txt kept (not yet published).' -ForegroundColor DarkGray
    }
    Write-Host '  Pass -RefreshMetadata to rewrite it from mod.info.' -ForegroundColor DarkGray
}
else {
    $lines = @('version=1')
    if ($existingId) { $lines += "id=$existingId" }
    if ($kept.Contains('title')) { $lines += "title=$($kept['title'])" }
    else { $lines += "title=$($info['name'])" }

    # description is one key per line, repeated - a single long line renders as
    # an unbroken wall of text on the Workshop page.
    foreach ($chunk in ($info['description'] -split '(?<=\.)\s+')) {
        if ($chunk.Trim()) { $lines += "description=$($chunk.Trim())" }
    }
    if ($info.ContainsKey('url')) {
        $lines += 'description='
        $lines += "description=Source and issues: $($info['url'])"
    }

    if ($kept.Contains('tags')) { $lines += "tags=$($kept['tags'])" }
    else { $lines += 'tags=Build 42' }

    if ($kept.Contains('visibility')) { $lines += "visibility=$($kept['visibility'])" }
    else { $lines += 'visibility=public' }

    if (-not $DryRun) {
        # No BOM. Set-Content -Encoding utf8 writes one in Windows PowerShell
        # 5.1, and the parser reads the first key as "﻿version".
        $utf8NoBom = New-Object System.Text.UTF8Encoding($false)
        [System.IO.File]::WriteAllLines($workshopTxt, $lines, $utf8NoBom)
    }

    $what = if ($hasWorkshopTxt) { 'rewritten' } else { 'created' }
    Write-Host "  workshop.txt $what." -ForegroundColor Green
    if ($existingId) {
        Write-Host "  Kept published item id=$existingId." -ForegroundColor DarkGray
    }
}

# ------------------------------------------------------------------ verify --

if (-not $DryRun) {
    $copied = @(Get-ChildItem -LiteralPath $stagedMod -Force -Recurse -File)
    if ($copied.Count -ne $sourceFiles.Count) {
        Write-Warning "Expected $($sourceFiles.Count) file(s) staged, found $($copied.Count)."
    }
}

Write-Host ''
Write-Host '  Done. In game: Main Menu > Workshop > Create/Update, then pick' -ForegroundColor Green
Write-Host "  '$ItemName' from the list." -ForegroundColor Green
Write-Host '  Check the title and description in workshop.txt before uploading.' -ForegroundColor DarkGray
Write-Host ''
