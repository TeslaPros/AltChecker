<#
Author: TeslaPro
Description:
Searches for a user-provided string inside files with selected extensions
under a base path, then exports matching results to a CSV file.
#>

# Define file extensions to search and the base path
$extensions = "*.txt", "*.log", "*.jar", "*.json"
$path = "C:\Users"
$ErrorActionPreference = 'SilentlyContinue'

# Use a generic list for better performance than array +=
$results = [System.Collections.Generic.List[object]]::new()

# Function to format timespans in a human-readable format
function Format-TimeSpan {
    param (
        [Parameter(Mandatory = $true)]
        [TimeSpan]$TimeSpan
    )

    if ($TimeSpan.TotalHours -ge 1) {
        return "{0:h\h\ mm\m\ ss\s}" -f $TimeSpan
    }
    elseif ($TimeSpan.TotalMinutes -ge 1) {
        return "{0:mm\m\ ss\s}" -f $TimeSpan
    }
    else {
        return "{0:ss\s}" -f $TimeSpan
    }
}

Clear-Host

# Header
Write-Host "===============================================" -ForegroundColor Cyan
Write-Host "             ADVANCED ALT CHECK                " -ForegroundColor Cyan
Write-Host "===============================================" -ForegroundColor Cyan
Write-Host ""

# Instructions
Write-Host "This script will search for a string in all files" -ForegroundColor Yellow
Write-Host "with the following extensions: $($extensions -join ', ')" -ForegroundColor Yellow
Write-Host "inside the path: $path" -ForegroundColor Yellow
Write-Host ""

# Prompt user input
$searchString = Read-Host "Enter the string to search for"
Write-Host ""

if ([string]::IsNullOrWhiteSpace($searchString)) {
    Write-Host "No search string was provided. Exiting." -ForegroundColor Red
    exit
}

Write-Host "Starting search..." -ForegroundColor Green
Write-Host ""

# Gather all matching files in one operation
Write-Host "Scanning files..." -ForegroundColor Gray
$allFiles = Get-ChildItem -Path $path -Include $extensions -Recurse -File
$total = $allFiles.Count

if ($total -eq 0) {
    Write-Host "No files found with the specified extensions." -ForegroundColor Red
    exit
}

Write-Host "Found $total files to examine." -ForegroundColor Gray
Start-Sleep -Seconds 1

# Initialize progress tracking
$i = 0
$stopwatch = [System.Diagnostics.Stopwatch]::StartNew()

foreach ($file in $allFiles) {
    $i++
    $percentComplete = [math]::Round(($i / $total) * 100, 1)

    if ($i -gt 1) {
        $elapsedSeconds = $stopwatch.Elapsed.TotalSeconds
        $averageTimePerFile = $elapsedSeconds / $i
        $filesRemaining = $total - $i
        $estimatedSecondsRemaining = $averageTimePerFile * $filesRemaining
        $timeRemaining = [TimeSpan]::FromSeconds($estimatedSecondsRemaining)
        $formattedTimeRemaining = Format-TimeSpan -TimeSpan $timeRemaining
    }
    else {
        $formattedTimeRemaining = "Calculating..."
    }

    $statusText = "Files: $i/$total ($percentComplete%) - Time remaining: $formattedTimeRemaining"
    $activityText = "Processing: $($file.Name)"
    Write-Progress -Activity $activityText -Status $statusText -PercentComplete $percentComplete

    try {
        $content = Get-Content -Path $file.FullName -Raw -ErrorAction Stop

        # Case-insensitive search
        if ($content -and $content.IndexOf($searchString, [System.StringComparison]::OrdinalIgnoreCase) -ge 0) {
            $results.Add([PSCustomObject]@{
                FileName      = $file.FullName
                StringMatched = $searchString
                FileSize      = "{0:N2} KB" -f ($file.Length / 1KB)
                LastModified  = $file.LastWriteTime
            })
        }
    }
    catch {
        # Silent by design
    }
}

$stopwatch.Stop()
$ErrorActionPreference = 'Continue'

# Results header
Write-Host ""
Write-Host "===============================================" -ForegroundColor Cyan
Write-Host "                 MATCH RESULTS                 " -ForegroundColor Cyan
Write-Host "===============================================" -ForegroundColor Cyan
Write-Host ""

$totalTime = $stopwatch.Elapsed
$formattedTotalTime = Format-TimeSpan -TimeSpan $totalTime

if ($results.Count -gt 0) {
    Write-Host "Found $($results.Count) files containing '$searchString'" -ForegroundColor Green
    Write-Host "Total processing time: $formattedTotalTime" -ForegroundColor Yellow

    if ($totalTime.TotalSeconds -gt 0) {
        Write-Host "Average files processed per second: $([math]::Round($total / $totalTime.TotalSeconds, 2))" -ForegroundColor Yellow
    }

    Write-Host ""

    # Save results to CSV
    $timestamp = Get-Date -Format "yyyyMMdd-HHmmss"
    $outputPath = Join-Path -Path (Get-Location) -ChildPath "SearchResults-$timestamp.csv"
    $results | Export-Csv -Path $outputPath -NoTypeInformation -Encoding UTF8

    Write-Host "Results saved to: $outputPath" -ForegroundColor Green
    Write-Host ""

    Write-Host "First $([Math]::Min(5, $results.Count)) matches:" -ForegroundColor White
    $results | Select-Object -First 5 | Format-Table -AutoSize -Property FileName, FileSize, LastModified
}
else {
    Write-Host "No matches found for '$searchString'" -ForegroundColor Yellow
    Write-Host "Total processing time: $formattedTotalTime" -ForegroundColor Yellow
}

Write-Host ""
Write-Host "===============================================" -ForegroundColor Cyan