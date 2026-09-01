<#
.SYNOPSIS
    Deploys the H:AW mod into the local Project Zomboid mods folder.

.DESCRIPTION
    Copies <repo>\SHAW\ into %USERPROFILE%\Zomboid\mods\SHAW\.

    If the destination folder already exists, its contents are wiped first, so
    files deleted or renamed in the repo do not linger in the installed copy.
    If it does not exist, it is created.

    Local dev script - not tracked by git.

.PARAMETER ModId
    Name of the folder created under Zomboid\mods. Must match the mod.info id.

.PARAMETER ZomboidPath
    The Zomboid user folder. Override if yours is not under %USERPROFILE%.

.PARAMETER DryRun
    Print what would happen without touching anything.

.EXAMPLE
    .\deploy.ps1
    .\deploy.ps1 -DryRun
#>

[CmdletBinding()]
param(
    [string]$ModId = 'SHAW',
    [string]$ZomboidPath = (Join-Path $env:USERPROFILE 'Zomboid'),
    [switch]$DryRun
)

$ErrorActionPreference = 'Stop'

# ---------------------------------------------------------------- resolve --

$sourcePath = Join-Path $PSScriptRoot $ModId

if (-not (Test-Path -LiteralPath $sourcePath)) {
    throw "Source folder not found: $sourcePath"
}

# Guard against deploying an empty or wrong folder.
$modInfo = Join-Path $sourcePath 'mod.info'
if (-not (Test-Path -LiteralPath $modInfo)) {
    throw "No mod.info in $sourcePath - is this the right folder?"
}

$modsRoot = Join-Path $ZomboidPath 'mods'
if (-not (Test-Path -LiteralPath $modsRoot)) {
    throw "Zomboid mods folder not found: $modsRoot`nPass -ZomboidPath if yours is elsewhere."
}

$destinationPath = Join-Path $modsRoot $ModId

# Safety check: whatever we are about to delete must sit inside Zomboid\mods.
# Resolve the parent (which exists) and append the leaf, so this works whether
# or not the destination itself exists yet.
$resolvedModsRoot = (Resolve-Path -LiteralPath $modsRoot).ProviderPath.TrimEnd('\')
$resolvedDestination = Join-Path $resolvedModsRoot $ModId

if ($resolvedDestination -eq $resolvedModsRoot -or
    -not $resolvedDestination.StartsWith($resolvedModsRoot + '\', [StringComparison]::OrdinalIgnoreCase)) {
    throw "Refusing to operate on '$resolvedDestination' - it is not inside '$resolvedModsRoot'."
}

Write-Host ''
Write-Host "  Source      : $sourcePath"
Write-Host "  Destination : $resolvedDestination"
if ($DryRun) { Write-Host '  Mode        : DRY RUN (nothing will be written)' -ForegroundColor Yellow }
Write-Host ''

# ------------------------------------------------------------------ clean --

if (Test-Path -LiteralPath $resolvedDestination) {
    $existing = @(Get-ChildItem -LiteralPath $resolvedDestination -Force -Recurse -File)
    Write-Host "  Folder exists - clearing $($existing.Count) file(s)..." -ForegroundColor DarkGray

    if (-not $DryRun) {
        Get-ChildItem -LiteralPath $resolvedDestination -Force |
            Remove-Item -Recurse -Force -Confirm:$false
    }
}
else {
    Write-Host '  Folder does not exist - creating it...' -ForegroundColor DarkGray
    if (-not $DryRun) {
        New-Item -ItemType Directory -Path $resolvedDestination -Force | Out-Null
    }
}

# ------------------------------------------------------------------- copy --

$sourceFiles = @(Get-ChildItem -LiteralPath $sourcePath -Force -Recurse -File)

if (-not $DryRun) {
    Copy-Item -Path (Join-Path $sourcePath '*') -Destination $resolvedDestination -Recurse -Force
}

Write-Host "  Copied $($sourceFiles.Count) file(s)." -ForegroundColor Green

# ---------------------------------------------------------------- verify --

if (-not $DryRun) {
    $copied = @(Get-ChildItem -LiteralPath $resolvedDestination -Force -Recurse -File)
    if ($copied.Count -ne $sourceFiles.Count) {
        Write-Warning "Expected $($sourceFiles.Count) file(s) at the destination, found $($copied.Count)."
    }
}

# ------------------------------------------------------- workshop clash --

# Once the mod is published, a second copy of it lives under Zomboid\Workshop.
# Both declare the same mod id, and the Workshop copy is the one the game
# loads - so deploying here alone silently changes nothing, and you test the
# staged build without knowing it. That cost a full test cycle once.
$stagedMod = Join-Path $ZomboidPath "Workshop\$ModId\Contents\mods\$ModId"

if (Test-Path -LiteralPath $stagedMod) {
    $newest = (Get-ChildItem -LiteralPath $sourcePath -Recurse -File |
        Measure-Object -Property LastWriteTimeUtc -Maximum).Maximum
    $staged = (Get-ChildItem -LiteralPath $stagedMod -Recurse -File |
        Measure-Object -Property LastWriteTimeUtc -Maximum).Maximum

    if ($staged -lt $newest) {
        Write-Host ''
        Write-Warning ("A Workshop copy of '$ModId' is staged and is OLDER than this build. " +
                       'The game loads that one, so it will hide what you just deployed. ' +
                       "Run build.ps1 as well.")
    }
    else {
        Write-Host '  Workshop copy is in step.' -ForegroundColor DarkGray
    }
}

Write-Host ''
Write-Host '  Done. Enable "Humans: Are Weak" in the in-game Mods menu, then start a save.' -ForegroundColor Green
Write-Host '  Lua errors go to %USERPROFILE%\Zomboid\console.txt' -ForegroundColor DarkGray
Write-Host ''
