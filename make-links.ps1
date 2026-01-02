# ====================================== HOW TO USE =====================================
# Create file make-links.psd1 with the following content :
#
# @{
#     SourceRoot = "C:\Path\To\LuaRoot"
#     DestRoot   = "C:\Path\To\LinkRoot"
#     IgnoreList = @() # Extra entries to ignore when syncing files.
# }
#
# Replace SourceRoot to the absolute path to the /src directory.
# Replace DestRoot to the absolute path to starframe's directory in your Starfall folder.

param (
    [Parameter(Mandatory = $false)] [switch] $Watch,
    [Parameter(Mandatory = $false)] [switch] $Force
)

# Path to config file
$CONFIG_PATH = ".\make-links.psd1"

# List of files to exclude (relative, extensionless)
$IGNORE_LIST = @(
    "lib\schema"
)

# Load config
if (-not (Test-Path $CONFIG_PATH)) {
    throw "Config file not found: $CONFIG_PATH"
}

$config = Import-PowerShellDataFile $CONFIG_PATH
$luaRoot = $config.LuaRoot
$starfallRoot = $config.StarfallRoot

$IGNORE_LIST += ($config.IgnoreList ?? @())

if (-not $luaRoot -or -not $starfallRoot) {
    throw "LuaRoot and StarfallRoot must be defined in the configuration file."
}

# Creates a hard link for a file given its relative source and destination (also changes extension).
function CreateLink
{
    param
    (
        [Parameter(Mandatory = $true)] [String] $FullPath,
        [Parameter(Mandatory = $true)] [String] $Source,
        [Parameter(Mandatory = $true)] [String] $Destination,
        [Parameter(Mandatory = $true)] [String] $NewExtension,
        [Parameter(Mandatory = $false)] [switch] $Force, 
        [Parameter(Mandatory = $false)] [switch] $IgnoreExistingFiles
    )

    if (-not (Test-Path $FullPath))
    {
        throw "File '$FullPath' does not exist."
    }

    if (-not (Test-Path $Destination))
    {
        New-Item -ItemType Directory -Path $Destination -Force | Out-Null
    }

    $relativePath = $FullPath.Substring($Source.Length).TrimStart('\')
    $tweakedRelativePath = [System.IO.Path]::ChangeExtension($relativePath, $NewExtension)
    $newFullPath = Join-Path $Destination $tweakedRelativePath

    if (Test-Path $newFullPath)
    {
        if ($Force.IsPresent)
        {
            Write-Warning "Deleting existing file at '$newFullPath'"
            Remove-Item $newFullPath -Force
        } 
        elseif ($IgnoreExistingFiles.IsPresent)
        {
            return
        }
        else
        {
            throw "File already present at '$newFullPath'."
        }
    }

    New-Item -ItemType HardLink -Path $newFullPath -Target $FullPath | Out-Null
    Write-Host "Creating hard link from '$FullPath' to '$newFullPath'"
}

function TrimPath {
    param (
        [String] $FullPath,
        [String] $BaseDirectory
    )
    
    return [System.IO.Path]::ChangeExtension($FullPath.Substring($BaseDirectory.Length).TrimStart('\'), "").TrimEnd('.')
}

# Ensure starfall root exists
if (-not (Test-Path $starfallRoot))
{
    New-Item -ItemType Directory -Path $starfallRoot | Out-Null
}

$luaFiles = Get-ChildItem -Path $luaRoot -Recurse -File -Filter *.lua
$txtFiles = Get-ChildItem -Path $starfallRoot -Recurse -File -Filter *.txt

# Create missing files from Lua to Starfall (.lua -> .txt)
foreach ($luaFile in $luaFiles)
{
    if ($IGNORE_LIST -contains (TrimPath -FullPath $luaFile.FullName -BaseDirectory $luaRoot)) { continue }
    CreateLink -FullPath $luaFile.FullName -Source $luaRoot -Destination $starfallRoot -NewExtension ".txt" -IgnoreExistingFiles -Force:$Force
}

# Create missing files from Starfall to Lua (.txt -> .lua)
foreach ($txtFile in $txtFiles)
{
    if ($IGNORE_LIST -contains (TrimPath -FullPath $txtFile.FullName -BaseDirectory $starfallRoot)) { continue }
    CreateLink -FullPath $txtFile.FullName -Source $starfallRoot -Destination $luaRoot -NewExtension ".lua" -IgnoreExistingFiles -Force:$Force
}


# Watcher part
if (-not $Watch.IsPresent) { return }

$luaWatcher = New-Object System.IO.FileSystemWatcher
$luaWatcher.Path = $luaRoot
$luaWatcher.IncludeSubdirectories = $true
$luaWatcher.EnableRaisingEvents = $true

$txtWatcher = New-Object System.IO.FileSystemWatcher
$txtWatcher.Path = $starfallRoot
$txtWatcher.IncludeSubdirectories = $true
$txtWatcher.EnableRaisingEvents = $true

# Register watcher for lua -> starfall sync
Register-ObjectEvent -InputObject $luaWatcher -EventName "Created" -MessageData $txtWatcher -Action {
    $fullPath = $Event.SourceEventArgs.FullPath
    $txtWatcher = $Event.MessageData

    if ([System.IO.Path]::GetExtension($fullPath) -ne ".lua") { return }
    if ($IGNORE_LIST -contains (TrimPath -FullPath $luaFile.FullName -BaseDirectory $luaRoot)) { return }

    $txtWatcher.EnableRaisingEvents = $false
    CreateLink -FullPath $fullPath -Source $luaRoot -Destination $starfallRoot -NewExtension ".txt" -Force
    Start-Sleep -Milliseconds 100
    $txtWatcher.EnableRaisingEvents = $true
}
Write-Host "Watching folder '$luaRoot' for created files."

# Register watcher for starfall -> lua sync
Register-ObjectEvent -InputObject $txtWatcher -EventName "Created" -MessageData $luaWatcher -Action {
    $fullPath = $Event.SourceEventArgs.FullPath
    $luaWatcher = $Event.MessageData

    if ([System.IO.Path]::GetExtension($fullPath) -ne ".txt") { return }
    if ($IGNORE_LIST -contains (TrimPath -FullPath $fullPath -BaseDirectory $starfallRoot)) { return }

    $luaWatcher.EnableRaisingEvents = $false
    CreateLink -FullPath $fullPath -Source $starfallRoot -Destination $luaRoot -NewExtension ".lua" -Force
    Start-Sleep -Milliseconds 100
    $luaWatcher.EnableRaisingEvents = $true
}
Write-Host "Watching folder '$starfallRoot' for created files."

Write-Host "Press Ctrl+C to stop."

while ($true) { Start-Sleep -Seconds 1 }