<#
.SYNOPSIS
    TeslaPro Style - Minecraft Audit & Beheer Tool.
.DESCRIPTION
    Scant het systeem naar Minecraft launchers en accounts met een premium tool layout.
#>

$ErrorActionPreference = "Stop"

# --- OMGEVINGSVARIABELEN ---
$AppData    = [Environment]::GetFolderPath("ApplicationData")
$LocalAppData = [Environment]::GetFolderPath("LocalApplicationData")
$UserProfile = [Environment]::GetFolderPath("UserProfile")

$ExportPathJson = Join-Path $PSScriptRoot "Minecraft_Audit_Report.json"
$ExportPathTxt  = Join-Path $PSScriptRoot "Minecraft_Audit_Report.txt"

# --- TESLAPRO THEMA LOGGING ---
function Write-TeslaHeader {
    Clear-Host
    Write-Host "===============================================================================" -ForegroundColor Cyan
    Write-Host "  ████████╗███████╗███████╗██╗      █████╗ ██████╗ ██████╗  ██████╗ " -ForegroundColor DarkCyan
    Write-Host "  ╚══██╔══╝██╔════╝██╔════╝██║     ██╔══██╗██╔══██╗██╔══██╗██╔═══██╗" -ForegroundColor DarkCyan
    Write-Host "     ██║   █████╗  ███████╗██║     ███████║██████╔╝██████╔╝██║   ██║" -ForegroundColor Cyan
    Write-Host "     ██║   ██╔══╝  ╚════██║██║     ██╔══██║██╔═══╝ ██╔══██╗██║   ██║" -ForegroundColor Cyan
    Write-Host "     ██║   ███████╗███████║███████╗██║  ██║██║     ██║  ██║╚██████╔╝" -ForegroundColor Blue
    Write-Host "     ╚═╝   ╚══════╝╚══════╝╚══════╝╚═╝  ╚═╝╚═╝     ╚═╝  ╚═╝ ╚═════╝ " -ForegroundColor Blue
    Write-Host "                      [+] MINECRAFT AUDIT & MANAGER [+]                        " -ForegroundColor White
    Write-Host "===============================================================================" -ForegroundColor Cyan
    Write-Host " [SYSTEM] Windows Audit Mode Active" -ForegroundColor Yellow
    Write-Host " [STATUS] Read-Only / Safe Mode Enabled (No network connections)" -ForegroundColor Green
    Write-Host "===============================================================================" -ForegroundColor Cyan
    Write-Host ""
}

function Write-TeslaLog {
    param (
        [Parameter(Mandatory=$true)][string]$Message,
        [Parameter(Mandatory=$false)][string]$Level = "INFO"
    )
    switch ($Level.ToUpper()) {
        "INFO"    { Write-Host " [*] " -NoNewline -ForegroundColor Cyan; Write-Host $Message -ForegroundColor White }
        "SUCCESS" { Write-Host " [+] " -NoNewline -ForegroundColor Green; Write-Host $Message -ForegroundColor Green }
        "WARN"    { Write-Host " [!] " -NoNewline -ForegroundColor Yellow; Write-Host $Message -ForegroundColor Yellow }
        "ERROR"   { Write-Host " [-] " -NoNewline -ForegroundColor Red; Write-Host $Message -ForegroundColor Red }
    }
}

# --- HELPER: VEILIG BESTANDEN LEZEN ---
function Safe-GetContent {
    param ([string]$Path)
    if (Test-Path $Path) {
        try { return Get-Content $Path -Raw -ErrorAction SilentlyContinue } catch { return $null }
    }
    return $null
}

# --- DETECTIE FUNCTIES ---

function Audit-OfficialMinecraft {
    Write-TeslaLog "Scanning: Official Minecraft Launcher..." "INFO"
    $Path = Join-Path $AppData ".minecraft"
    $Result = @{ Launcher = "Official Launcher"; Location = $Path; GameDirs = @(); Profiles = @(); Accounts = @() }

    if (Test-Path $Path) {
        $Result.GameDirs += $Path
        $ProfilesJson = Safe-GetContent (Join-Path $Path "launcher_profiles.json")
        if ($ProfilesJson) {
            try {
                $Obj = ConvertFrom-Json $ProfilesJson
                foreach ($P in $Obj.profiles.PSObject.Properties) {
                    $Result.Profiles += $P.Value.name
                    if ($P.Value.gameDir) { $Result.GameDirs += $P.Value.gameDir }
                }
            } catch {}
        }
        $AccountsJson = Safe-GetContent (Join-Path $Path "launcher_accounts.json")
        if ($AccountsJson) {
            try {
                $Obj = ConvertFrom-Json $AccountsJson
                foreach ($Acc in $Obj.accounts.PSObject.Properties) {
                    if ($Acc.Value.username) { $Result.Accounts += $Acc.Value.username }
                }
            } catch {}
        }
        return $Result
    }
    return $null
}

function Audit-MinecraftBedrock {
    Write-TeslaLog "Scanning: Minecraft Bedrock (UWP)..." "INFO"
    $Path = Join-Path $LocalAppData "Packages\Microsoft.MinecraftUWP_8wekyb3d8bbwe\LocalState\games\com.mojang"
    if (Test-Path $Path) {
        return @{ Launcher = "Bedrock Edition"; Location = "UWP AppData"; GameDirs = @($Path); Profiles = @("Default UWP"); Accounts = @("Xbox Live Linked") }
    }
    return $null
}

function Audit-PrismLauncher {
    Write-TeslaLog "Scanning: Prism Launcher..." "INFO"
    $Path = Join-Path $AppData "PrismLauncher"
    if (-not (Test-Path $Path)) { $Path = Join-Path $LocalAppData "PrismLauncher" }
    if (Test-Path $Path) {
        $Result = @{ Launcher = "Prism Launcher"; Location = $Path; GameDirs = @(); Profiles = @(); Accounts = @() }
        $InstPath = Join-Path $Path "instances"
        if (Test-Path $InstPath) {
            $Result.GameDirs += $InstPath
            Get-ChildItem $InstPath -Directory | ForEach-Object { $Result.Profiles += $_.Name }
        }
        $AccJson = Safe-GetContent (Join-Path $Path "accounts.json")
        if ($AccJson) {
            try {
                $Obj = ConvertFrom-Json $AccJson
                foreach ($Acc in $Obj.accounts) { $Result.Accounts += $Acc.username }
            } catch {}
        }
        return $Result
    }
    return $null
}

function Audit-MultiMC {
    Write-TeslaLog "Scanning: MultiMC..." "INFO"
    $Paths = @(Join-Path $AppData "MultiMC", Join-Path $LocalAppData "MultiMC", "C:\MultiMC")
    foreach ($P in $Paths) {
        if (Test-Path $P) {
            $Result = @{ Launcher = "MultiMC"; Location = $P; GameDirs = @(); Profiles = @(); Accounts = @() }
            $InstPath = Join-Path $P "instances"
            if (Test-Path $InstPath) {
                $Result.GameDirs += $InstPath
                Get-ChildItem $InstPath -Directory | ForEach-Object { $Result.Profiles += $_.Name }
            }
            return $Result
        }
    }
    return $null
}

function Audit-LunarClient {
    Write-TeslaLog "Scanning: Lunar Client..." "INFO"
    $Path = Join-Path $UserProfile ".lunarclient"
    if (Test-Path $Path) {
        $Result = @{ Launcher = "Lunar Client"; Location = $Path; GameDirs = @(Join-Path $Path "offline"); Profiles = @(); Accounts = @() }
        $Json = Safe-GetContent (Join-Path $Path "settings\game\settings.json")
        if ($Json) {
            try { $Result.Profiles += (ConvertFrom-Json $Json).profiles } catch {}
        }
        return $Result
    }
    return $null
}

function Audit-BadlionClient {
    Write-TeslaLog "Scanning: Badlion Client..." "INFO"
    $Path = Join-Path $AppData "Badlion Client"
    if (Test-Path $Path) {
        return @{ Launcher = "Badlion Client"; Location = $Path; GameDirs = @(Join-Path $AppData ".minecraft"); Profiles = @("Badlion Default"); Accounts = @("See Official Config") }
    }
    return $null
}

function Audit-FeatherClient {
    Write-TeslaLog "Scanning: Feather Client..." "INFO"
    $Path = Join-Path $AppData ".feather"
    if (Test-Path $Path) {
        return @{ Launcher = "Feather Client"; Location = $Path; GameDirs = @($Path); Profiles = @("Feather Default"); Accounts = @("See Official Config") }
    }
    return $null
}

function Audit-TechnicLauncher {
    Write-TeslaLog "Scanning: Technic Launcher..." "INFO"
    $Path = Join-Path $AppData ".technic"
    if (Test-Path $Path) {
        $Result = @{ Launcher = "Technic Launcher"; Location = $Path; GameDirs = @(); Profiles = @(); Accounts = @() }
        if (Test-Path (Join-Path $Path "modpacks")) {
            Get-ChildItem (Join-Path $Path "modpacks") -Directory | ForEach-Object { $Result.Profiles += $_.Name; $Result.GameDirs += $_.FullName }
        }
        return $Result
    }
    return $null
}

function Audit-CurseForge {
    Write-TeslaLog "Scanning: CurseForge..." "INFO"
    $Path = Join-Path $LocalAppData "Overwolf\CurseForge"
    $CustomPath = Join-Path $UserProfile "CurseForge\Minecraft\Instances"
    if (-not (Test-Path $CustomPath)) { $CustomPath = Join-Path $AppData "CurseForge\Minecraft\Instances" }
    if ((Test-Path $Path) -or (Test-Path $CustomPath)) {
        $Result = @{ Launcher = "CurseForge"; Location = $Path; GameDirs = @(); Profiles = @(); Accounts = @() }
        if (Test-Path $CustomPath) {
            $Result.GameDirs += $CustomPath
            Get-ChildItem $CustomPath -Directory | ForEach-Object { $Result.Profiles += $_.Name }
        }
        return $Result
    }
    return $null
}

function Audit-ATLauncher {
    Write-TeslaLog "Scanning: ATLauncher..." "INFO"
    $Paths = @(Join-Path $AppData "ATLauncher", Join-Path $LocalAppData "ATLauncher", "C:\ATLauncher")
    foreach ($P in $Paths) {
        if (Test-Path $P) {
            $Result = @{ Launcher = "ATLauncher"; Location = $P; GameDirs = @(); Profiles = @(); Accounts = @() }
            if (Test-Path (Join-Path $P "instances")) {
                $Result.GameDirs += Join-Path $P "instances"
                Get-ChildItem (Join-Path $P "instances") -Directory | ForEach-Object { $Result.Profiles += $_.Name }
            }
            return $Result
        }
    }
    return $null
}

# --- MAIN ENGINE ---
function Main {
    Write-TeslaHeader
    
    $AuditResults = @()
    $ScanFunctions = @("Audit-OfficialMinecraft", "Audit-MinecraftBedrock", "Audit-PrismLauncher", "Audit-MultiMC", "Audit-LunarClient", "Audit-BadlionClient", "Audit-FeatherClient", "Audit-TechnicLauncher", "Audit-CurseForge", "Audit-ATLauncher")

    foreach ($Function in $ScanFunctions) {
        try {
            $Data = Invoke-Expression $Function
            if ($Data -ne $null) {
                $Data.Profiles = ($Data.Profiles | Select-Object -Unique) -join ", "
                $Data.Accounts = ($Data.Accounts | Select-Object -Unique) -join ", "
                $Data.GameDirs = ($Data.GameDirs | Select-Object -Unique) -join "; "
                
                if ([string]::IsNullOrEmpty($Data.Profiles)) { $Data.Profiles = "None" }
                if ([string]::IsNullOrEmpty($Data.Accounts)) { $Data.Accounts = "None" }
                
                $AuditResults += [PSCustomObject]$Data
            }
        } catch {
            Write-TeslaLog "Error executing $Function" "ERROR"
        }
    }

    Write-Host ""
    if ($AuditResults.Count -eq 0) {
        Write-TeslaLog "No Minecraft installations detected on this machine." "WARN"
        return
    }

    Write-TeslaLog "Scan completed successfully! Outputting results..." "SUCCESS"
    Write-Host ""

    # --- THEMA RESULTATEN DISPLAY (TeslaPro Grid) ---
    Write-Host "===============================================================================" -ForegroundColor Cyan
    Write-Host "                           [ DETECTED LAUNCHERS ]                              " -ForegroundColor White
    Write-Host "===============================================================================" -ForegroundColor Cyan
    
    foreach ($Item in $AuditResults) {
        Write-Host " [>] Launcher   : " -NoNewline -ForegroundColor Cyan; Write-Host $Item.Launcher -ForegroundColor White
        Write-Host "     Profiles   : " -NoNewline -ForegroundColor DarkCyan; Write-Host $Item.Profiles -ForegroundColor Gray
        Write-Host "     Accounts   : " -NoNewline -ForegroundColor DarkCyan; Write-Host $Item.Accounts -ForegroundColor Green
        Write-Host "     Directory  : " -NoNewline -ForegroundColor DarkCyan; Write-Host $Item.Location -ForegroundColor DarkGray
        Write-Host "-------------------------------------------------------------------------------" -ForegroundColor Blue
    }

    # EXPORTS (Stil op de achtergrond)
    try {
        $AuditResults | ConvertTo-Json -Depth 4 | Out-File -FilePath $ExportPathJson -Encoding utf8 -Force
        $TxtReport = New-Object System.Text.StringBuilder
        foreach ($Item in $AuditResults) {
            [void]$TxtReport.AppendLine("Launcher: $($Item.Launcher) | Profiles: $($Item.Profiles) | Accounts: $($Item.Accounts)")
        }
        $TxtReport.ToString() | Out-File -FilePath $ExportPathTxt -Encoding utf8 -Force
        
        Write-TeslaLog "Reports saved to script directory (JSON & TXT)." "SUCCESS"
    } catch {
        Write-TeslaLog "Failed to save backup logs." "WARN"
    }
    
    Write-Host "===============================================================================" -ForegroundColor Cyan
    Write-Host " [FINISHED] Press any key to exit..." -ForegroundColor Yellow
}

Main