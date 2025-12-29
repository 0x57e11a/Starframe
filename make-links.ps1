# ====================================== HOW TO USE =====================================
# Create file make-links.psd1 with the following content :
#
# @{
#     SourceRoot = "C:\Path\To\LuaRoot"
#     DestRoot   = "C:\Path\To\LinkRoot"
# }
#
# Replace SourceRoot to the absolute path to the /src directory.
# Replace DestRoot to the absolute path to starframe's directory in your Starfall folder.

# Path to config file
$ConfigPath = ".\make-links.psd1"

# Load config
if (-not (Test-Path $ConfigPath)) {
    throw "Config file not found: $ConfigPath"
}

$config = Import-PowerShellDataFile $ConfigPath

$SourceRoot = $config.SourceRoot
$DestRoot   = $config.DestRoot

if (-not $SourceRoot -or -not $DestRoot) {
    throw "SourceRoot and DestRoot must be defined in the config file."
}

# Ensure destination root exists
if (-not (Test-Path $DestRoot)) {
    New-Item -ItemType Directory -Path $DestRoot | Out-Null
}

Get-ChildItem -Path $SourceRoot -Recurse -File -Filter *.lua | ForEach-Object {

    # Get relative path from source root
    $relativePath = $_.FullName.Substring($SourceRoot.Length).TrimStart('\')

    # Change extension to .txt
    $relativeTxtPath = [System.IO.Path]::ChangeExtension($relativePath, ".txt")

    # Build destination path
    $destFilePath = Join-Path $DestRoot $relativeTxtPath

    # Ensure destination directory exists
    $destDir = Split-Path $destFilePath -Parent
    if (-not (Test-Path $destDir)) {
        New-Item -ItemType Directory -Path $destDir -Force | Out-Null
    }

    # Create hard link (overwrite if exists)
    if (Test-Path $destFilePath) {
        Remove-Item $destFilePath -Force
    }

    New-Item -ItemType HardLink -Path $destFilePath -Target $_.FullName | Out-Null
}