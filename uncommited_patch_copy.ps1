# Set UTF-8 encoding for PowerShell output
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8
$env:LANG = "en_US.UTF-8"

# Show header
Write-Host "`n=== Git Patch Generator ===" -ForegroundColor Cyan
Write-Host "This script will help you create a zip file containing changes between two commits`n" -ForegroundColor Cyan

# Get last 50 commits and display them
Write-Host "Fetching last 50 commits..." -ForegroundColor Yellow
$commits = git -c core.quotepath=false log --pretty=format:"%h - [%ad] %s" --date=format:"%Y-%m-%d %H:%M" -n 50 | Out-String
$commitArray = $commits -split "`n" | Where-Object { $_ -match '\S' }

# Display commits with index
Write-Host "`nAvailable commits (newest to oldest):" -ForegroundColor Green
for ($i = 0; $i -lt $commitArray.Count; $i++) {
    Write-Host "$($i+1). $($commitArray[$i])"
}

# Get user input for commits
Write-Host "`nPlease select commits by entering their numbers (1-50)" -ForegroundColor Yellow
Write-Host "For single commit comparison with HEAD, enter one number" -ForegroundColor Yellow
Write-Host "For commit range, enter two numbers separated by space" -ForegroundColor Yellow
$selection = Read-Host "Your selection"

# Process user input
$selectedIndexes = $selection -split ' ' | ForEach-Object { [int]$_ - 1 }

if ($selectedIndexes.Count -gt 2) {
    Write-Host "Error: Please select maximum 2 commits" -ForegroundColor Red
    exit 1
}

# Extract commit hashes
$selectedCommits = @()
foreach ($index in $selectedIndexes) {
    if ($index -ge 0 -and $index -lt $commitArray.Count) {
        $commitLine = $commitArray[$index]
        if ($commitLine -match '^([a-f0-9]+)') {
            $selectedCommits += $matches[1]
        }
    }
}

# Validate commit hashes
if ($selectedCommits.Count -eq 0) {
    Write-Host "Error: Invalid commit selection" -ForegroundColor Red
    exit 1
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
