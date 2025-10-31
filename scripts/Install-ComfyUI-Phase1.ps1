
#===========================================================================
# SECTION 1: SCRIPT CONFIGURATION & HELPER FUNCTIONS
#===========================================================================

param(
    [string]$InstallPath = (Split-Path -Path $PSScriptRoot -Parent),
    [switch]$RunAdminTasks # Flag pour le mode élevé
)
$comfyPath = Join-Path $InstallPath "ComfyUI"
$scriptPath = Join-Path $InstallPath "scripts"
$condaPath = Join-Path $env:LOCALAPPDATA "Miniconda3"
$condaExe = Join-Path $condaPath "Scripts\conda.exe"
$logPath = Join-Path $InstallPath "logs"
$logFile = Join-Path $logPath "install_log.txt"
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

# Charger les dépendances TÔT
$dependenciesFile = Join-Path $scriptPath "dependencies.json"
if (-not (Test-Path $dependenciesFile)) { Write-Host "FATAL: dependencies.json not found at '$dependenciesFile'..." -ForegroundColor Red; Read-Host; exit 1 }
try { $dependencies = Get-Content -Raw -Path $dependenciesFile | ConvertFrom-Json } catch { Write-Host "FATAL: Failed to parse dependencies.json. Error: $($_.Exception.Message)" -ForegroundColor Red; Read-Host; exit 1}
if (-not (Test-Path $logPath)) { try { New-Item -ItemType Directory -Force -Path $logPath | Out-Null } catch { Write-Host "WARN: Could not create log directory '$logPath'" -ForegroundColor Yellow } }

function Test-IsAdmin {
    try {
        $currentUser = New-Object Security.Principal.WindowsPrincipal $([Security.Principal.WindowsIdentity]::GetCurrent())
        return $currentUser.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
    } catch { return $false }
}

Import-Module (Join-Path $PSScriptRoot "UmeAiRTUtils.psm1") -Force

#===========================================================================
# SECTION 2: MAIN SCRIPT EXECUTION
#===========================================================================
$global:totalSteps = 8 # Phase 1 = Setup Admin (si besoin) + Setup Conda Env + Lancement Phase 2
$global:currentStep = 0

if ($RunAdminTasks) {
    Write-Host "`n=== Performing Administrator Tasks ===`n" -ForegroundColor Cyan

    # Tâche 1 : Long paths
    Write-Host "[Admin Task 1/2] Enabling support for long paths (Registry)..." -ForegroundColor Yellow
    $regPath = "HKLM:\SYSTEM\CurrentControlSet\Control\FileSystem"; $regKey = "LongPathsEnabled"
    try {
        if ((Get-ItemPropertyValue -Path $regPath -Name $regKey -ErrorAction SilentlyContinue) -ne 1) {
            Set-ItemProperty -Path $regPath -Name $regKey -Value 1 -Type DWord -Force -ErrorAction Stop
            Write-Host "- Long path support enabled." -ForegroundColor Green
        } else { Write-Host "- Long path support already enabled." -ForegroundColor Green }
    } catch { Write-Host "- ERROR: Unable to enable long paths. $_" -ForegroundColor Red }

    # Tâche 2 : VS Build Tools
    Write-Host "[Admin Task 2/2] Checking/Installing VS Build Tools..." -ForegroundColor Yellow
    $depFileAdmin = Join-Path $scriptPath "dependencies.json"
    $vsToolAdmin = $null
    if (Test-Path $depFileAdmin) {
        try { $depsAdmin = Get-Content -Raw -Path $depFileAdmin | ConvertFrom-Json } catch { $depsAdmin = $null }
        if ($depsAdmin -ne $null -and $depsAdmin.PSObject.Properties.Name -contains 'tools' -and $depsAdmin.tools.PSObject.Properties.Name -contains 'vs_build_tools') {
             $vsToolAdmin = $depsAdmin.tools.vs_build_tools
        }
    }
    if ($vsToolAdmin -ne $null -and $vsToolAdmin.install_path) {
        $vsInstallCheckPathAdmin = $ExecutionContext.InvokeCommand.ExpandString($vsToolAdmin.install_path)
        if (-not (Test-Path $vsInstallCheckPathAdmin)) {
            Write-Host "- Installing VS Build Tools..." -ForegroundColor Yellow
            $vsInstallerAdmin = Join-Path $env:TEMP "vs_buildtools_admin.exe"
            try {
                [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
                Invoke-WebRequest -Uri $vsToolAdmin.url -OutFile $vsInstallerAdmin -UseBasicParsing -ErrorAction Stop
                Write-Host "- Launching the VS Build Tools installer (may take some time)..."
                Start-Process -FilePath $vsInstallerAdmin -ArgumentList $vsToolAdmin.arguments -Wait -ErrorAction Stop
                Remove-Item $vsInstallerAdmin -ErrorAction SilentlyContinue
                Write-Host "- VS Build Tools installed." -ForegroundColor Green
            } catch { Write-Host "- ERROR: Failed to download/install VS Build Tools. $_" -ForegroundColor Red }
        } else { Write-Host "- VS Build Tools already installed." -ForegroundColor Green }
    } else { Write-Host "- ERROR: Unable to find VS Build Tools information in '$depFileAdmin'." -ForegroundColor Red }

    Write-Host "`n=== Administrative tasks completed. Closing this window. ===" -ForegroundColor Green
    Start-Sleep -Seconds 3
    exit 0

} else {
    $needsElevation = $false
    Write-Log "Checking for prerequisites that may require admin rights..." -Level 1
    # Long paths
    if ((Get-ItemPropertyValue -Path "HKLM:\SYSTEM\CurrentControlSet\Control\FileSystem" -Name "LongPathsEnabled" -ErrorAction SilentlyContinue) -ne 1) {
        Write-Log "Long path support must be enabled (Admin required)." -Level 2 -Color Yellow; $needsElevation = $true
    } else { Write-Log "Long path support OK." -Level 2 -Color Green }
    # VS Build Tools
    if ($dependencies -ne $null -and $dependencies.tools -ne $null -and $dependencies.tools.vs_build_tools -ne $null -and $dependencies.tools.vs_build_tools.install_path) {
        $vsInstallCheckPath = $ExecutionContext.InvokeCommand.ExpandString($dependencies.tools.vs_build_tools.install_path)
        if (-not (Test-Path $vsInstallCheckPath)) {
            Write-Log "VS Build Tools must be installed (Admin required)." -Level 2 -Color Yellow; $needsElevation = $true
        } else { Write-Log "VS Build Tools OK." -Level 2 -Color Green }
    } else { Write-Log "WARNING: Unable to verify VS Build Tools. Elevation may be required." -Level 2 -Color Yellow; $needsElevation = $true }

    if ($needsElevation -and -not (Test-IsAdmin)) {
        Write-Host "`nAdministrator privileges are required for initial setup." -ForegroundColor Yellow
        Write-Host "Re-running part of the script with elevation..." -ForegroundColor Yellow
        Write-Host "Please accept the UAC prompt." -ForegroundColor Yellow
        $psArgs = "-ExecutionPolicy Bypass -NoProfile -File `"$($MyInvocation.MyCommand.Definition)`" -RunAdminTasks -InstallPath `"$InstallPath`""
        try {
            $adminProcess = Start-Process powershell.exe -Verb RunAs -ArgumentList $psArgs -Wait -PassThru -ErrorAction Stop
            if ($adminProcess.ExitCode -ne 0) { throw "The administrator process failed (code $($adminProcess.ExitCode))." }
            Write-Host "`nAdmin configuration completed successfully. Resuming installation..." -ForegroundColor Green; Start-Sleep 2
        } catch {
            Write-Host "ERROR: Elevation failed or admin script failed: $($_.Exception.Message)" -ForegroundColor Red
            Read-Host "Press Enter to exit."; exit 1
        }
    } elseif ($needsElevation -and (Test-IsAdmin)) {
         Write-Host "`nWARNING: The script was run as Admin, but elevation was required." -ForegroundColor Yellow
         Write-Host "Admin tasks will be performed, but the rest will also run as Admin." -ForegroundColor Yellow
         Write-Log "[Admin Tasks within User Script] Performing Admin tasks..." -Level 1
         $regPath = "HKLM:\SYSTEM\CurrentControlSet\Control\FileSystem"; $regKey = "LongPathsEnabled"
         try { Set-ItemProperty -Path $regPath -Name $regKey -Value 1 -Type DWord -Force -ErrorAction Stop; Write-Log "[Admin] Long paths OK." -Level 2 } catch { Write-Log "[Admin] ERREUR Long paths" -Level 2 -Color Red}
    }
	
    Clear-Host
    Write-Host "-------------------------------------------------------------------------------"
    $asciiBanner = @'
                          __  __               ___    _ ____  ______
                         / / / /___ ___  ___  /   |  (_) __ \/_  __/
                        / / / / __ `__ \/ _ \/ /| | / / /_/ / / / 
                       / /_/ / / / / / /  __/ ___ |/ / _, _/ / /
                       \____/_/ /_/ /_/\___/_/  |_/_/_/ |_| /_/
'@
    Write-Host $asciiBanner -ForegroundColor Cyan
    Write-Host "-------------------------------------------------------------------------------"
    Write-Host "                           ComfyUI - Auto-Installer                            " -ForegroundColor Yellow
    Write-Host "                                  Version 4.0                                  " -ForegroundColor White
    Write-Host "-------------------------------------------------------------------------------"


    # --- Step 1: Setup Miniconda and Conda Environment ---
    Write-Log "Setting up Miniconda and Conda Environment" -Level 0 # Étape 1/2
    if (-not (Test-Path $condaPath)) {
        Write-Log "Miniconda not found. Installing..." -Level 1 -Color Yellow
        $minicondaInstaller = Join-Path $env:TEMP "Miniconda3-latest-Windows-x86_64.exe"
        $minicondaUrl = $dependencies.tools.miniconda.url 
        if (-not $minicondaUrl) { $minicondaUrl = "https://repo.anaconda.com/miniconda/Miniconda3-latest-Windows-x86_64.exe" }
        Download-File -Uri $minicondaUrl -OutFile $minicondaInstaller 
        Invoke-AndLog $minicondaInstaller "/InstallationType=JustMe /RegisterPython=0 /S /D=`"$condaPath`""
        Remove-Item $minicondaInstaller -ErrorAction SilentlyContinue
    } else { Write-Log "Miniconda is already installed at '$condaPath'" -Level 1 -Color Green }

    if (-not (Test-Path $condaExe)) { Write-Log "FATAL ERROR: conda.exe not found after installation/verification" -Color Red; Read-Host "Press Enter."; exit 1 }

    Write-Log "Accepting Anaconda Terms of Service..." -Level 1
    Invoke-AndLog "$condaExe" "tos accept --override-channels --channel https://repo.anaconda.com/pkgs/main"
	Invoke-AndLog "$condaExe" "tos accept --override-channels --channel https://repo.anaconda.com/pkgs/r"
	Invoke-AndLog "$condaExe" "tos accept --override-channels --channel https://repo.anaconda.com/pkgs/msys2"
	Write-Log "Installing aria2 via direct download..." -Level 1
    $aria2Url = "https://github.com/aria2/aria2/releases/download/release-1.37.0/aria2-1.37.0-win-64bit-build1.zip"
    $aria2ZipPath = Join-Path $env:TEMP "aria2.zip"
    $aria2InstallPath = Join-Path $env:LOCALAPPDATA "aria2" 
    $aria2ExePath = Join-Path $aria2InstallPath "aria2c.exe"

    if (-not (Test-Path $aria2ExePath)) {
        Write-Log "Downloading aria2..." -Level 2
        try {
            Download-File -Uri $aria2Url -OutFile $aria2ZipPath 
            Write-Log "Extracting aria2..." -Level 2
            # Crée le dossier d'installation s'il n'existe pas
            if (-not (Test-Path $aria2InstallPath)) { New-Item -ItemType Directory -Path $aria2InstallPath -Force | Out-Null }
            # Extrait SEULEMENT aria2c.exe du zip (nécessite PowerShell 5+)
            Expand-Archive -Path $aria2ZipPath -DestinationPath $aria2InstallPath -Force
            # Recherche le .exe dans le dossier extrait (le nom peut varier légèrement selon la version du zip)
            $extractedExe = Get-ChildItem -Path $aria2InstallPath -Filter "aria2c.exe" -Recurse | Select-Object -First 1
            if ($extractedExe) {
                 # Déplace l'exe à la racine du dossier aria2 s'il est dans un sous-dossier
                 if ($extractedExe.DirectoryName -ne $aria2InstallPath) {
                     Move-Item -Path $extractedExe.FullName -Destination $aria2InstallPath -Force
                     # Optionnel : Supprimer le reste du dossier extrait s'il existe
                     Remove-Item -Path $extractedExe.DirectoryName -Recurse -Force -ErrorAction SilentlyContinue
                 }
                 Write-Log "aria2c.exe installed successfully to '$aria2InstallPath'." -Level 2 -Color Green
            } else {
                 throw "aria2c.exe not found within the extracted archive."
            }
        } catch {
            Write-Log "ERREUR: Failed to download or extract aria2. Error: $($_.Exception.Message)" -Level 1 -Color Red
            Write-Log "Downloads will be slower (Invoke-WebRequest)." -Level 2
        } finally {
             # Nettoie le zip
             if (Test-Path $aria2ZipPath) { Remove-Item $aria2ZipPath -ErrorAction SilentlyContinue }
        }
    } else {
         Write-Log "aria2c.exe already found at '$aria2InstallPath'." -Level 1 -Color Green
    }

    Write-Log "Attempting to remove old 'UmeAiRT' environment for a clean install..." -Level 1
    Invoke-AndLog "$condaExe" "env remove -n UmeAiRT -y" -IgnoreErrors
    Write-Log "Creating new Conda environment 'UmeAiRT' from '$scriptPath\environment.yml'..." -Level 1
    Invoke-AndLog "$condaExe" "env create -f `"$scriptPath\environment.yml`""
	Write-Log "Environment 'UmeAiRT' created successfully." -Level 2 -Color Green

    Write-Log "Conda environment ready." -Level 1 -Color Green
    Write-Log "Phase 2 of the installation has been launched..." -Level 0

    $phase2LauncherPath = Join-Path $scriptPath "Launch-Phase2.bat"
    $phase2ScriptPath = Join-Path $scriptPath "Install-ComfyUI-Phase2.ps1"

    $launcherContent = @"
@echo off
echo Activando entorno UmeAiRT...
call "$($condaExe -replace 'conda.exe', 'activate.bat')" UmeAiRT
if %errorlevel% neq 0 (
    echo FAILED to activate the Conda 'UmeAirT' environment.
    pause
    exit /b %errorlevel%
)
echo Phase 2 Launch...
powershell.exe -ExecutionPolicy Bypass -NoProfile -File "$phase2ScriptPath" -InstallPath "$InstallPath"
echo End of Phase 2. Press Enter to close this window.
pause
"@
    try { $launcherContent | Out-File -FilePath $phase2LauncherPath -Encoding utf8 -ErrorAction Stop } catch { Write-Log "ERROR: Unable to create '$phase2LauncherPath'." -Color Red; Read-Host "Press Enter."; exit 1 }

    Write-Log "A new window will open for Phase 2..." -Level 2
    try { Start-Process -FilePath $phase2LauncherPath -Wait -ErrorAction Stop } catch { Write-Log "ERROR: Unable to launch Phase 2 ($($_.Exception.Message))." -Color Red; Read-Host "Press Enter."; exit 1 }

    #===========================================================================
    # FINALIZATION 
    #===========================================================================
    Write-Log "-------------------------------------------------------------------------------" -Color Green
    Write-Log "Phase 1 is complete. Phase 2 was executed in a separate window." -Color Green
}