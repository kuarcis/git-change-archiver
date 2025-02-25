# Set UTF-8 encoding for PowerShell output
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8
$env:LANG = "en_US.UTF-8"

# Show header
Write-Host "`n=== Git Change Archiver v 1.0 ===" -ForegroundColor Cyan
Write-Host "This script will help you create a zip file containing changes between two commits`n" -ForegroundColor Cyan

# Get last 50 commits and display them
Write-Host "Fetching last 50 commits..." -ForegroundColor Yellow
$commits = git -c core.quotepath=false log --pretty=format:"%h - [%ad] %s" --date=format:"%Y-%m-%d %H:%M" -n 50 | Out-String
$commitArray = $commits -split "`n" | Where-Object { $_ -match '\S' }

function Show-CommitList {
    param (
        [string[]]$commits,
        [int]$startIndex = 0
    )
    for ($i = $startIndex; $i -lt $commits.Count; $i++) {
        Write-Host "$($i+1). $($commits[$i])"
    }
}

function Get-FirstCommit {
    Write-Host "`nAvailable commits (newest to oldest):" -ForegroundColor Green
    Show-CommitList -commits $commitArray
    
    while ($true) {
        Write-Host "`nPlease select the first commit, content in the commit WON'T include in the output(1-50):" -ForegroundColor Yellow
        $selection = Read-Host "Your selection"
        
        if ($selection -match '^\d+$') {
            $index = [int]$selection - 1
            if ($index -ge 0 -and $index -lt $commitArray.Count) {
                return $index
            }
        }
        Write-Host "Invalid selection. Please try again." -ForegroundColor Red
    }
}

function Get-SecondCommit {
    param (
        [int]$firstIndex
    )
    
    Write-Host "`nSelected first commit: $($commitArray[$firstIndex])" -ForegroundColor Cyan
    Write-Host "`nAvailable commits (newer than selected, oldest to newest):" -ForegroundColor Green
    
    # Show commits newer than the selected one in reverse order
    $newerCommits = $commitArray[0..$firstIndex]
    [array]::Reverse($newerCommits)
    Show-CommitList -commits $newerCommits
    
    while ($true) {
        Write-Host "`nPlease select the second commit (1-$($firstIndex + 1)) or:" -ForegroundColor Yellow
        Write-Host "- Press Enter to use HEAD" -ForegroundColor Yellow
        Write-Host "- Type 'back' to reselect first commit" -ForegroundColor Yellow
        $selection = Read-Host "Your selection"
        
        if ($selection -eq 'back') {
            return $null
        }
        
        if ([string]::IsNullOrWhiteSpace($selection)) {
            return "HEAD"
        }
        
        if ($selection -match '^\d+$') {
            $selectedIndex = [int]$selection - 1
            if ($selectedIndex -ge 0 -and $selectedIndex -le $firstIndex) {
                return $newerCommits[$selectedIndex]
            }
        }
        Write-Host "Invalid selection. Please try again." -ForegroundColor Red
    }
}

# Get commit selections
$selectedCommits = @()
while ($true) {
    $firstIndex = Get-FirstCommit
    $firstCommit = $commitArray[$firstIndex]
    if ($firstCommit -match '^([a-f0-9]+)') {
        $firstHash = $matches[1]
    }
    
    $secondSelection = Get-SecondCommit -firstIndex $firstIndex
    if ($null -eq $secondSelection) {
        continue
    }
    
    if ($secondSelection -eq "HEAD") {
        $selectedCommits = @($firstHash)
    } else {
        if ($secondSelection -match '^([a-f0-9]+)') {
            $secondHash = $matches[1]
            $selectedCommits = @($secondHash, $firstHash)
        }
    }
    break
}

# Determine old and new commits
$oldCommit = $selectedCommits[-1]
$newCommit = if ($selectedCommits.Count -eq 1) { "HEAD" } else { $selectedCommits[0] }

# Generate default filename with date
$date = Get-Date -Format "yyyyMMdd"
$defaultFilename = "${oldCommit}_${newCommit}_${date}.zip"

# Create patch directory if it doesn't exist
$defaultPath = "patch"
if (-not (Test-Path $defaultPath)) {
    New-Item -ItemType Directory -Force -Path $defaultPath | Out-Null
}

# Get custom output path
Write-Host "`nEnter output path (press Enter to use default: $defaultPath):" -ForegroundColor Yellow
$outputPath = Read-Host
$outputPath = if ([string]::IsNullOrWhiteSpace($outputPath)) { $defaultPath } else { $outputPath }

# Create output directory if it doesn't exist
if (-not (Test-Path $outputPath)) {
    New-Item -ItemType Directory -Force -Path $outputPath | Out-Null
}

# Get custom filename
Write-Host "Enter filename (press Enter to use default: $defaultFilename):" -ForegroundColor Yellow
$customFilename = Read-Host
$filename = if ([string]::IsNullOrWhiteSpace($customFilename)) { $defaultFilename } else { $customFilename }

# Ensure filename ends with .zip
if (-not $filename.EndsWith(".zip")) {
    $filename = "$filename.zip"
}

# Get line ending preference
Write-Host "`nSelect line ending format:" -ForegroundColor Yellow
Write-Host "1. LF (Unix/Linux style - default)" -ForegroundColor Green
Write-Host "2. CRLF (Windows style)" -ForegroundColor Green
$lineEndingChoice = Read-Host "Enter choice (press Enter for default)"

# Set line ending based on choice
$lineEnding = switch ($lineEndingChoice) {
    "2" { "`r`n" }
    default { "`n" }
}

# Combine path and filename
$fullPath = Join-Path $outputPath $filename

Write-Host "`nGenerating patch file..." -ForegroundColor Yellow
Write-Host "From commit: $oldCommit" -ForegroundColor Cyan
Write-Host "To commit: $newCommit" -ForegroundColor Cyan
Write-Host "Output file: $fullPath" -ForegroundColor Cyan
Write-Host "Line ending: $(if ($lineEnding -eq "`n") { "LF" } else { "CRLF" })" -ForegroundColor Cyan

# Get the list of changed files
$changedFiles = git diff --name-only $oldCommit $newCommit

if (-not $changedFiles) {
    Write-Host "Error: No changes found between the selected commits" -ForegroundColor Red
    exit 1
}

# Create temporary directory for changed files
$tempDir = "temp_patch_$date"
New-Item -ItemType Directory -Force -Path $tempDir | Out-Null

try {
    # Copy changed files to temp directory preserving directory structure
    foreach ($file in $changedFiles) {
        $targetPath = Join-Path $tempDir $file
        $targetDir = Split-Path -Parent $targetPath
        if (-not (Test-Path $targetDir)) {
            New-Item -ItemType Directory -Force -Path $targetDir | Out-Null
        }

        # Get file content and normalize line endings
        $content = git show "$newCommit`:$file" | Out-String
        $normalizedContent = $content -replace "`r?`n", $lineEnding

        # Write content with specified line ending
        [System.IO.File]::WriteAllText($targetPath, $normalizedContent)
    }

    # Create zip file
    Compress-Archive -Path "$tempDir/*" -DestinationPath $fullPath -Force

    if (Test-Path $fullPath) {
        Write-Host "`nSuccess! Patch file created: $fullPath" -ForegroundColor Green
    } else {
        Write-Host "`nError: Failed to create patch file" -ForegroundColor Red
    }
} finally {
    # Cleanup temp directory
    if (Test-Path $tempDir) {
        Remove-Item -Recurse -Force $tempDir
    }
}
