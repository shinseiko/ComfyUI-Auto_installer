
#===========================================================================
# SECTION 1: SCRIPT CONFIGURATION & HELPER FUNCTIONS
#===========================================================================

param(
    [string]$InstallPath,
    [switch]$RunAdminTasks # Flag for elevated mode
)
$comfyPath = Join-Path $InstallPath "ComfyUI"
$scriptPath = Join-Path $InstallPath "scripts"
$condaPath = Join-Path $env:LOCALAPPDATA "Miniconda3"
$condaExe = Join-Path $condaPath "Scripts\conda.exe"
$logPath = Join-Path $InstallPath "logs"
$logFile = Join-Path $logPath "install_log.txt"
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

# Load dependencies EARLY
$dependenciesFile = Join-Path $scriptPath "dependencies.json"
if (-not (Test-Path $dependenciesFile)) { Write-Host "FATAL: dependencies.json not found at '$dependenciesFile'..." -ForegroundColor Red; Read-Host; exit 1 }
try { $dependencies = Get-Content -Raw -Path $dependenciesFile | ConvertFrom-Json } catch { Write-Host "FATAL: Failed to parse dependencies.json. Error: $($_.Exception.Message)" -ForegroundColor Red; Read-Host; exit 1 }
if (-not (Test-Path $logPath)) { try { New-Item -ItemType Directory -Force -Path $logPath | Out-Null } catch { Write-Host "WARN: Could not create log directory '$logPath'" -ForegroundColor Yellow } }

function Test-IsAdmin {
    try {
        $currentUser = New-Object Security.Principal.WindowsPrincipal $([Security.Principal.WindowsIdentity]::GetCurrent())
        return $currentUser.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
    }
    catch { return $false }
}

Import-Module (Join-Path $scriptPath "UmeAiRTUtils.psm1") -Force

#===========================================================================
# SECTION 2: MAIN SCRIPT EXECUTION
#===========================================================================
$global:totalSteps = 9 # Phase 1 = Setup Admin (if needed) + Setup Env + Launch Phase 2
$global:currentStep = 0

if ($RunAdminTasks) {
    Write-Host "`n=== Performing Administrator Tasks ===`n" -ForegroundColor Cyan

    # Task 1: Long paths
    Write-Host "[Admin Task 1/2] Enabling support for long paths (Registry)..." -ForegroundColor Yellow
    $regPath = "HKLM:\SYSTEM\CurrentControlSet\Control\FileSystem"; $regKey = "LongPathsEnabled"
    try {
        if ((Get-ItemPropertyValue -Path $regPath -Name $regKey -ErrorAction SilentlyContinue) -ne 1) {
            Set-ItemProperty -Path $regPath -Name $regKey -Value 1 -Type DWord -Force -ErrorAction Stop
            Write-Host "- Long path support enabled." -ForegroundColor Green
        }
        else { Write-Host "- Long path support already enabled." -ForegroundColor Green }
    }
    catch { Write-Host "- ERROR: Unable to enable long paths. $_" -ForegroundColor Red }

    # Task 2: VS Build Tools
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
            }
            catch { Write-Host "- ERROR: Failed to download/install VS Build Tools. $_" -ForegroundColor Red }
        }
        else { Write-Host "- VS Build Tools already installed." -ForegroundColor Green }
    }
    else { Write-Host "- ERROR: Unable to find VS Build Tools information in '$depFileAdmin'." -ForegroundColor Red }

    Write-Host "`n=== Administrative tasks completed. Closing this window. ===" -ForegroundColor Green
    Start-Sleep -Seconds 3
    exit 0

}
else {
    $needsElevation = $false
    Write-Log "Checking for prerequisites that may require admin rights..." -Level 1
    # Long paths
    if ((Get-ItemPropertyValue -Path "HKLM:\SYSTEM\CurrentControlSet\Control\FileSystem" -Name "LongPathsEnabled" -ErrorAction SilentlyContinue) -ne 1) {
        Write-Log "Long path support must be enabled (Admin required)." -Level 2 -Color Yellow; $needsElevation = $true
    }
    else { Write-Log "Long path support OK." -Level 2 -Color Green }
    # VS Build Tools
    if ($dependencies -ne $null -and $dependencies.tools -ne $null -and $dependencies.tools.vs_build_tools -ne $null -and $dependencies.tools.vs_build_tools.install_path) {
        $vsInstallCheckPath = $ExecutionContext.InvokeCommand.ExpandString($dependencies.tools.vs_build_tools.install_path)
        if (-not (Test-Path $vsInstallCheckPath)) {
            Write-Log "VS Build Tools must be installed (Admin required)." -Level 2 -Color Yellow; $needsElevation = $true
        }
        else { Write-Log "VS Build Tools OK." -Level 2 -Color Green }
    }
    else { Write-Log "WARNING: Unable to verify VS Build Tools. Elevation may be required." -Level 2 -Color Yellow; $needsElevation = $true }

    if ($needsElevation -and -not (Test-IsAdmin)) {
        Write-Host "`nAdministrator privileges are required for initial setup." -ForegroundColor Yellow
        Write-Host "Re-running part of the script with elevation..." -ForegroundColor Yellow
        Write-Host "Please accept the UAC prompt." -ForegroundColor Yellow
        $psArgs = "-ExecutionPolicy Bypass -NoProfile -File `"$($MyInvocation.MyCommand.Definition)`" -RunAdminTasks -InstallPath `"$InstallPath`""
        try {
            $adminProcess = Start-Process powershell.exe -Verb RunAs -ArgumentList $psArgs -Wait -PassThru -ErrorAction Stop
            if ($adminProcess.ExitCode -ne 0) { throw "The administrator process failed (code $($adminProcess.ExitCode))." }
            Write-Host "`nAdmin configuration completed successfully. Resuming installation..." -ForegroundColor Green; Start-Sleep 2
        }
        catch {
            Write-Host "ERROR: Elevation failed or admin script failed: $($_.Exception.Message)" -ForegroundColor Red
            Read-Host "Press Enter to exit."; exit 1
        }
    }
    elseif ($needsElevation -and (Test-IsAdmin)) {
        Write-Host "`nWARNING: The script was run as Admin, but elevation was required." -ForegroundColor Yellow
        Write-Host "Admin tasks will be performed, but the rest will also run as Admin." -ForegroundColor Yellow
        Write-Log "[Admin Tasks within User Script] Performing Admin tasks..." -Level 1
        $regPath = "HKLM:\SYSTEM\CurrentControlSet\Control\FileSystem"; $regKey = "LongPathsEnabled"
        try { Set-ItemProperty -Path $regPath -Name $regKey -Value 1 -Type DWord -Force -ErrorAction Stop; Write-Log "[Admin] Long paths OK." -Level 2 } catch { Write-Log "[Admin] ERROR Long paths" -Level 2 -Color Red }
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
    Write-Host "                                 Version 4.2                                   " -ForegroundColor White
    Write-Host "-------------------------------------------------------------------------------"

    # --- Step 0: Choose Installation Type ---
    $validChoices = @("1", "2")
    Write-Host "`nChoose installation type:" -ForegroundColor Cyan
    Write-Host "1. Light (Recommended) - Uses your existing Python 3.12 (Standard venv)" -ForegroundColor Green
    Write-Host "2. Full - Installs Miniconda, Python 3.12, Git, CUDA (Isolated environment)" -ForegroundColor Yellow

    $installTypeChoice = ""
    while ($installTypeChoice -notin $validChoices) {
        $installTypeChoice = Read-Host "Enter choice (1 or 2)"
    }
    $installType = if ($installTypeChoice -eq "1") { "Light" } else { "Full" }
    $installTypeFile = Join-Path $scriptPath "install_type"
    $phase2LauncherPath = Join-Path $scriptPath "Launch-Phase2.bat"
    $phase2ScriptPath = Join-Path $scriptPath "Install-ComfyUI-Phase2.ps1"

    if ($installType -eq "Light") {
        Write-Log "Selected: Light Installation (venv)" -Level 0
        Set-Content -Path $installTypeFile -Value "venv" -Force

        # 1. Check for Python 3.12 using py launcher
        Write-Log "Checking for Python 3.12..." -Level 1
        $pythonCommand = $null
        $pythonArgs = $null

        # MÉTHODE A : Vérifier via le Python Launcher (py) - Syntaxe corrigée
        if (Get-Command 'py' -ErrorAction SilentlyContinue) {
            try {
                # On demande spécifiquement si la version 3.12 répond
                $pyVer = py -3.12 --version 2>&1
                if ($pyVer -match "Python 3\.12") {
                    Write-Log "Python Launcher detected with Python 3.12." -Level 1 -Color Green
                    $pythonCommand = "py"
                    $pythonArgs = "-3.12"
                }
            } catch {}
        }

        # MÉTHODE B : Vérifier via la commande système standard (python) si Méthode A échoue
        if ($null -eq $pythonCommand -and (Get-Command 'python' -ErrorAction SilentlyContinue)) {
            try {
                $sysVer = python --version 2>&1
                if ($sysVer -match "Python 3\.12") {
                    Write-Log "System Python 3.12 detected (standard PATH)." -Level 1 -Color Green
                    $pythonCommand = "python"
                    $pythonArgs = ""
                }
            } catch {}
        }

        # Si aucune méthode n'a fonctionné
        if ($null -eq $pythonCommand) {
            Write-Log "ERROR: Python 3.12 is required but not found." -Level 1 -Color Red
            Write-Log "Diagnostics:" -Level 2
            Write-Log "1. 'py -3.12 --version' did not return 3.12" -Level 2
            Write-Log "2. 'python --version' did not return 3.12" -Level 2
            Write-Log "Please install Python 3.12 from python.org and check 'Add to PATH' or ensure the launcher is installed." -Level 1 -Color Yellow
            Read-Host "Press Enter to exit."
            exit 1
        }

        # 3. Create venv using the detected command
        $venvPath = Join-Path $scriptPath "venv"
        if (-not (Test-Path $venvPath)) {
            Write-Log "Creating virtual environment (venv) at '$venvPath'..." -Level 1
            
            # Construction de la commande pour Invoke-AndLog
            $venvArgs = "$pythonArgs -m venv `"$venvPath`""
            # On nettoie les espaces en trop si pythonArgs est vide
            $venvArgs = $venvArgs.Trim()
            
            Invoke-AndLog $pythonCommand $venvArgs
        }
        else {
            Write-Log "Virtual environment already exists." -Level 1 -Color Green
        }

        # 2. Check Git (Implicitly required for later steps)
        try {
            $gitVer = git --version 2>&1
            Write-Log "Git detected: $gitVer" -Level 1 -Color Green
        }
        catch {
            Write-Log "WARNING: Git not found. It is recommended to have Git installed." -Level 1 -Color Yellow
        }

        # 4. Prepare Launch-Phase2.bat for venv
        $launcherContent = @"
@echo off
call "$venvPath\Scripts\activate.bat"
if %errorlevel% neq 0 (
    echo FAILED to activate venv.
    pause
    exit /b %errorlevel%
)
echo Phase 2 Launch (venv)...
powershell.exe -ExecutionPolicy Bypass -NoProfile -File "$phase2ScriptPath" -InstallPath "$InstallPath"
echo End of Phase 2. Press Enter to close this window.
pause
"@

    }
    else {
        # --- Step 1: Setup Miniconda and Conda Environment ---
        Write-Log "Selected: Full Installation (Miniconda)" -Level 0
        Set-Content -Path $installTypeFile -Value "conda" -Force

        Write-Log "Setting up Miniconda and Conda Environment" -Level 0
        if (-not (Test-Path $condaPath)) {
            Write-Log "Miniconda not found. Installing..." -Level 1 -Color Yellow
            $minicondaInstaller = Join-Path $env:TEMP "Miniconda3-latest-Windows-x86_64.exe"
            $minicondaUrl = $dependencies.tools.miniconda.url
            if (-not $minicondaUrl) { $minicondaUrl = "https://repo.anaconda.com/miniconda/Miniconda3-latest-Windows-x86_64.exe" }
            Save-File -Uri $minicondaUrl -OutFile $minicondaInstaller
            Write-Log "Running Miniconda installer (this may take a minute)..." -Level 2
            $installerProcess = Start-Process -FilePath $minicondaInstaller -ArgumentList "/InstallationType=JustMe /RegisterPython=0 /S /D=$condaPath" -Wait -PassThru
            if ($installerProcess.ExitCode -ne 0) {
                Write-Log "ERROR: Miniconda installer failed with exit code $($installerProcess.ExitCode)" -Level 1 -Color Red
                Read-Host "Press Enter to exit."
                exit 1
            }
            Write-Log "Miniconda installed successfully." -Level 2 -Color Green

            # Verify conda.exe exists with retry (installer may still be finishing)
            $retryCount = 0
            $maxRetries = 10
            while (-not (Test-Path $condaExe) -and $retryCount -lt $maxRetries) {
                $retryCount++
                Write-Log "Waiting for Miniconda installation to complete... ($retryCount/$maxRetries)" -Level 3
                Start-Sleep -Seconds 2
            }

            Remove-Item $minicondaInstaller -ErrorAction SilentlyContinue
        }
        else { Write-Log "Miniconda is already installed at '$condaPath'" -Level 1 -Color Green }

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
                Save-File -Uri $aria2Url -OutFile $aria2ZipPath
                Write-Log "Extracting aria2..." -Level 2
                # Create install dir if needed
                if (-not (Test-Path $aria2InstallPath)) { New-Item -ItemType Directory -Path $aria2InstallPath -Force | Out-Null }
                # Extract ONLY aria2c.exe
                Expand-Archive -Path $aria2ZipPath -DestinationPath $aria2InstallPath -Force
                # Find exe in extracted folder
                $extractedExe = Get-ChildItem -Path $aria2InstallPath -Filter "aria2c.exe" -Recurse | Select-Object -First 1
                if ($extractedExe) {
                    # Move to root of aria2 folder
                    if ($extractedExe.DirectoryName -ne $aria2InstallPath) {
                        Move-Item -Path $extractedExe.FullName -Destination $aria2InstallPath -Force
                        # Optional cleanup
                        Remove-Item -Path $extractedExe.DirectoryName -Recurse -Force -ErrorAction SilentlyContinue
                    }
                    Write-Log "aria2c.exe installed successfully to '$aria2InstallPath'." -Level 2 -Color Green
                }
                else {
                    throw "aria2c.exe not found within the extracted archive."
                }
            }
            catch {
                Write-Log "ERROR: Failed to download or extract aria2. Error: $($_.Exception.Message)" -Level 1 -Color Red
                Write-Log "Downloads will be slower (Invoke-WebRequest)." -Level 2
            }
            finally {
                # Clean zip
                if (Test-Path $aria2ZipPath) { Remove-Item $aria2ZipPath -ErrorAction SilentlyContinue }
            }
        }
        else {
            Write-Log "aria2c.exe already found at '$aria2InstallPath'." -Level 1 -Color Green
        }

        Write-Log "Attempting to remove old 'UmeAiRT' environment for a clean install..." -Level 1
        Invoke-AndLog "$condaExe" "env remove -n UmeAiRT -y" -IgnoreErrors
        Write-Log "Creating new Conda environment 'UmeAiRT' from '$scriptPath\environment.yml'..." -Level 1
        Invoke-AndLog "$condaExe" "env create -f `"$scriptPath\environment.yml`""
        Write-Log "Environment 'UmeAiRT' created successfully." -Level 2 -Color Green

        Write-Log "Conda environment ready." -Level 1 -Color Green

        # Prepare Launch-Phase2.bat for Conda
        $launcherContent = @"
@echo off
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
    }

    # Write Launcher
    try { 
        # UTF-8 no BOM
        $utf8NoBom = New-Object System.Text.UTF8Encoding $false
        [System.IO.File]::WriteAllLines($phase2LauncherPath, $launcherContent, $utf8NoBom)
    }
    catch {
        Write-Log "ERROR: Unable to create '$phase2LauncherPath'. $($_.Exception.Message)" -Color Red
        Read-Host "Press Enter."
        exit 1 
    }

    Write-Log "Phase 2 of the installation has been launched..." -Level 0
    Write-Log "A new window will open for Phase 2..." -Level 2
    try { Start-Process -FilePath $phase2LauncherPath -Wait -ErrorAction Stop } catch { Write-Log "ERROR: Unable to launch Phase 2 ($($_.Exception.Message))." -Color Red; Read-Host "Press Enter."; exit 1 }

    #===========================================================================
    # FINALIZATION 
    #===========================================================================
    Write-Log "-------------------------------------------------------------------------------" -Color Green
    Write-Log "Phase 1 is complete. Phase 2 was executed in a separate window." -Color Green
}
