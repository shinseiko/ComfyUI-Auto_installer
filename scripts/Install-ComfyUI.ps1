#Requires -RunAsAdministrator

<#
.SYNOPSIS
    An automated installer for ComfyUI and its dependencies.
.DESCRIPTION
    This script streamlines the setup of ComfyUI, including Python, Git,
    all required Python packages, custom nodes, and optional models.
#>

#===========================================================================
# SECTION 1: SCRIPT CONFIGURATION & HELPER FUNCTIONS
#===========================================================================

param(
    [string]$InstallPath = (Split-Path -Path $PSScriptRoot -Parent)
)
$comfyPath = Join-Path $InstallPath "ComfyUI"
$scriptPath = Join-Path $InstallPath "scripts"
$condaPath = Join-Path $env:LOCALAPPDATA "Miniconda3"
$condaExe = Join-Path $condaPath "Scripts\conda.exe"
$logPath = Join-Path $InstallPath "logs"
$logFile = Join-Path $logPath "install_log.txt"
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

#$dependenciesFile = Join-Path (Split-Path -Path $MyInvocation.MyCommand.Definition -Parent) "dependencies.json"
#if (-not (Test-Path $dependenciesFile)) { Write-Host "FATAL: dependencies.json not found..." -ForegroundColor Red; Read-Host; exit 1 }
#$dependencies = Get-Content -Raw -Path $dependenciesFile | ConvertFrom-Json
if (-not (Test-Path $logPath)) { New-Item -ItemType Directory -Force -Path $logPath | Out-Null }

function Write-Log {
    param([string]$Message, [int]$Level = 1, [string]$Color = "Default")
    $prefix = ""
    $defaultColor = "White"
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    switch ($Level) {
        -2 { $prefix = "" }
        0 {
            $global:currentStep++
            $wrappedMessage = "| [Step $($global:currentStep)/$($global:totalSteps)] $Message |"
            $separator = "=" * ($wrappedMessage.Length)
            $consoleMessage = "`n$separator`n$wrappedMessage`n$separator"
            $logMessage = "[$timestamp] [Step $($global:currentStep)/$($global:totalSteps)] $Message"
            $defaultColor = "Yellow"
        }
        1 { $prefix = "  - " }
        2 { $prefix = "    -> " }
        3 { $prefix = "      [INFO] " }
    }
    if ($Color -eq "Default") { $Color = $defaultColor }
    if ($Level -ne 0) {
        $logMessage = "[$timestamp] $($prefix.Trim()) $Message"
        $consoleMessage = "$prefix$Message"
    }
    Write-Host $consoleMessage -ForegroundColor $Color
    Add-Content -Path $logFile -Value $logMessage
}

function Invoke-AndLog {
    param(
        [string]$File,
        [string]$Arguments
    )
    
    # Path to a unique temporary log file.
    $tempLogFile = Join-Path $env:TEMP ([System.Guid]::NewGuid().ToString() + ".tmp")

    try {
        # Execute the command and redirect ALL of its output to the temporary file.
        $commandToRun = "`"$File`" $Arguments"
        $cmdArguments = "/C `"$commandToRun > `"`"$tempLogFile`"`" 2>&1`""
        Start-Process -FilePath "cmd.exe" -ArgumentList $cmdArguments -Wait -WindowStyle Hidden
        
        # Once the command is complete, read the temporary file.
        if (Test-Path $tempLogFile) {
            $output = Get-Content $tempLogFile
            # Append the output to the main log file.
            Add-Content -Path $logFile -Value $output
        }
    } catch {
        Write-Log "FATAL ERROR trying to execute command: $commandToRun" -Color Red
    } finally {
        # Ensure the temporary file is always deleted.
        if (Test-Path $tempLogFile) {
            Remove-Item $tempLogFile
        }
    }
}

function Download-File {
    param([string]$Uri, [string]$OutFile)
    Write-Log "Downloading `"$($Uri.Split('/')[-1])`"" -Level 2 -Color DarkGray
    Invoke-AndLog "powershell.exe" "-NoProfile -Command `"[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12; Invoke-WebRequest -Uri '$Uri' -OutFile '$OutFile'`""
}

function Invoke-Conda-Command {
    param(
        [string]$Command,
        [string]$Arguments
    )
    # Plus besoin de $condaRun, on utilise $condaExe qui est défini globalement
    Invoke-AndLog $condaExe "run -n UmeAiRT $Command $Arguments"
}

#===========================================================================
# SECTION 2: MAIN SCRIPT EXECUTION
#===========================================================================
Write-Host "`n>>> CONFIRMATION: RUNNING FINAL SCRIPT <<<`n" -ForegroundColor Green
Write-Log "DEBUG: Loaded tools config: $($dependencies.tools | ConvertTo-Json -Depth 3)" -Level 3
$global:totalSteps = 11
$global:currentStep = 0
$totalCores = [int]$env:NUMBER_OF_PROCESSORS
$optimalParallelJobs = [int][Math]::Floor(($totalCores * 3) / 4)
if ($optimalParallelJobs -lt 1) { $optimalParallelJobs = 1 }

Clear-Host
# --- Bannière ---
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
Write-Host "                                  Version 3.2                                  " -ForegroundColor White
Write-Host "-------------------------------------------------------------------------------"

# --- Step 1: Setup Miniconda and Conda Environment ---
Write-Log "Setting up Miniconda and Conda Environment" -Level 0
if (-not (Test-Path $condaPath)) {
    Write-Log "Miniconda not found. Installing..." -Level 1 -Color Yellow
    $minicondaInstaller = Join-Path $env:TEMP "Miniconda3-latest-Windows-x86_64.exe"
    Download-File -Uri "https://repo.anaconda.com/miniconda/Miniconda3-py312_25.7.0-2-Windows-x86_64.exe" -OutFile $minicondaInstaller
    Start-Process -FilePath $minicondaInstaller -ArgumentList "/InstallationType=JustMe /RegisterPython=0 /S /D=$condaPath" -Wait
    Remove-Item $minicondaInstaller
} else {
    Write-Log "Miniconda is already installed" -Level 1 -Color Green
}
Write-Log "Accepting Anaconda Terms of Service..." -Level 1
Invoke-AndLog "$condaExe" "config --set anaconda_tos_accepted yes -y"
Invoke-AndLog "$condaExe" "tos accept --override-channels --channel https://repo.anaconda.com/pkgs/main -y"
Invoke-AndLog "$condaExe" "tos accept --override-channels --channel https://repo.anaconda.com/pkgs/r -y"
Invoke-AndLog "$condaExe" "tos accept --override-channels --channel https://repo.anaconda.com/pkgs/msys2 -y"

$envExists = Invoke-AndLog "$condaExe" "env list" | Select-String -Pattern "UmeAiRT"
if (-not $envExists) {
    Write-Log "Creating Conda environment 'UmeAiRT'..." -Level 1
    Invoke-AndLog "$condaExe" "env create -f `"$scriptPath\environment.yml`""
} else {
    Write-Log "Conda environment 'UmeAiRT' already exists" -Level 1 -Color Green
}

# --- Step 2: Clone ComfyUI ---
Write-Log "Cloning ComfyUI" -Level 0
if (-not (Test-Path $comfyPath)) {
    Write-Log "Cloning ComfyUI repository from $($dependencies.repositories.comfyui.url)..." -Level 1
    $cloneArgs = "clone $($dependencies.repositories.comfyui.url) `"$comfyPath`""
    Invoke-Conda-Command "git" $cloneArgs

    if (-not (Test-Path $comfyPath)) {
        Write-Log "FATAL: ComfyUI cloning failed. Please check the logs." -Level 0 -Color Red
        Read-Host "Press Enter to exit."
        exit 1
    }
} else {
    Write-Log "ComfyUI directory already exists" -Level 1 -Color Green
}

# --- Step 3: Install Core Dependencies ---
Write-Log "Installing Core Dependencies" -Level 0
Write-Log "Upgrading pip and wheel" -Level 1
Invoke-Conda-Command "python" "-m pip install --upgrade $($dependencies.pip_packages.upgrade -join ' ')"
Write-Log "Installing torch packages" -Level 1
Invoke-Conda-Command "python" "-m pip install $($dependencies.pip_packages.torch.packages) --index-url $($dependencies.pip_packages.torch.index_url)"
Write-Log "Installing ComfyUI requirements" -Level 1
Invoke-Conda-Command "python" "-m pip install -r `"$comfyPath\$($dependencies.pip_packages.comfyui_requirements)`""

# --- Step 4: Install Custom Nodes ---
Write-Log "Installing Custom Nodes" -Level 0
$csvUrl = $dependencies.files.custom_nodes_csv.url
$csvPath = Join-Path $InstallPath $dependencies.files.custom_nodes_csv.destination
Download-File -Uri $csvUrl -OutFile $csvPath
$customNodes = Import-Csv -Path $csvPath
$customNodesPath = Join-Path $InstallPath "custom_nodes"
foreach ($node in $customNodes) {
    $nodeName = $node.Name
    $repoUrl = $node.RepoUrl
    $nodePath = if ($node.Subfolder) { Join-Path $customNodesPath $node.Subfolder } else { Join-Path $customNodesPath $nodeName }
    if (-not (Test-Path $nodePath)) {
        Write-Log "Installing $nodeName" -Level 1
        Invoke-Conda-Command "git" "clone $repoUrl `"$nodePath`""
        if ($node.RequirementsFile) {
            $reqPath = Join-Path $nodePath $node.RequirementsFile
            if (Test-Path $reqPath) {
                Write-Log "Installing requirements for $nodeName" -Level 2
                Invoke-Conda-Command "python" "-m pip install -r `"$reqPath`""
            }
        }
    }
    else {
        Write-Log "$nodeName (already exists, skipping)" -Level 1 -Color Green
    }
}

# --- Step 5: Install Final Python Dependencies ---
Write-Log "Installing Final Python Dependencies" -Level 0
Write-Log "Installing standard packages..." -Level 1
Invoke-Conda-Command "python" "-m pip install $($dependencies.pip_packages.standard -join ' ')"

Write-Log "Installing packages from .whl files..." -Level 1
foreach ($wheel in $dependencies.pip_packages.wheels) {
    Write-Log "Installing $($wheel.name)" -Level 2
    $wheelPath = Join-Path $InstallPath "$($wheel.name).whl"
    Download-File -Uri $wheel.url -OutFile $wheelPath
    Invoke-Conda-Command "python" "-m pip install `"$wheelPath`""
    Remove-Item $wheelPath -ErrorAction SilentlyContinue
}

Write-Log "Installing pinned version packages..." -Level 1
Invoke-Conda-Command "python" "-m pip install $($dependencies.pip_packages.pinned -join ' ')"

Write-Log "Installing packages from git repositories..." -Level 1
foreach ($repo in $dependencies.pip_packages.git_repos) {
    Write-Log "Installing $($repo.name)..." -Level 2
    $installUrl = "git+$($repo.url)@$($repo.commit)"
    $pipArgs = "-m pip install `"$installUrl`""
    if ($repo.name -eq "xformers") {
        $pipArgs = "-m pip install --no-build-isolation --verbose `"$installUrl`""
    }
    if ($repo.name -eq "apex") {
        $pipArgs = "-m pip install $($repo.install_options) `"$installUrl`""
    }
    Invoke-Conda-Command "python" $pipArgs
}

# --- Step 6: Download Workflows & Settings ---
Write-Log "Downloading Workflows & Settings..." -Level 0
$settingsFile = $dependencies.files.comfy_settings
$settingsDest = Join-Path $InstallPath $settingsFile.destination
$settingsDir = Split-Path $settingsDest -Parent
if (-not (Test-Path $settingsDir)) { New-Item -Path $settingsDir -ItemType Directory -Force | Out-Null }
Download-File -Uri $settingsFile.url -OutFile $settingsDest

$workflowRepo = $dependencies.repositories.workflows
$workflowCloneDest = Join-Path $InstallPath "user\default\workflows\UmeAiRT-Workflow"
if (-not (Test-Path $workflowCloneDest)) { 
    Invoke-Conda-Command "git" "clone $($workflowRepo.url) `"$workflowCloneDest`""
}

# --- Step 7: Optional Model Pack Downloads ---
Write-Log "Optional Model Pack Downloads" -Level 0

# Copy the base models directory if it exists
$ModelsSource = Join-Path $comfyPath "models"
if (Test-Path $ModelsSource) {
    Write-Log "Copying base models directory..." -Level 1
    Copy-Item -Path $ModelsSource -Destination $InstallPath -Recurse -Force
}

$modelPacks = @(
    @{Name="FLUX"; ScriptName="Download-FLUX-Models.ps1"},
    @{Name="WAN2.1"; ScriptName="Download-WAN2.1-Models.ps1"},
    @{Name="WAN2.2"; ScriptName="Download-WAN2.2-Models.ps1"},
    @{Name="HIDREAM"; ScriptName="Download-HIDREAM-Models.ps1"},
    @{Name="LTXV"; ScriptName="Download-LTXV-Models.ps1"}
    @{Name="QWEN"; ScriptName="Download-QWEN-Models.ps1"}
)
$scriptsSubFolder = Join-Path $InstallPath "scripts"

foreach ($pack in $modelPacks) {
    $scriptPath = Join-Path $scriptsSubFolder $pack.ScriptName
    if (-not (Test-Path $scriptPath)) {
        Write-Log "Model downloader script not found: '$($pack.ScriptName)'. Skipping." -Level 1 -Color Red
        continue 
    }

    $validInput = $false
    while (-not $validInput) {
        # Use Write-Log for the prompt to keep the color formatting.
        Write-Log "Would you like to download $($pack.Name) models? (Y/N)" -Level 1 -Color Yellow
        $choice = Read-Host

        if ($choice -eq 'Y' -or $choice -eq 'y') {
            Write-Log "Launching downloader for $($pack.Name) models..." -Level 2 -Color Green
            # The external script will handle its own logging.
            & $scriptPath -InstallPath $InstallPath
            $validInput = $true
        } elseif ($choice -eq 'N' -or $choice -eq 'n') {
            Write-Log "Skipping download for $($pack.Name) models." -Level 2
            $validInput = $true
        } else {
            # Use Write-Log for the error message.
            Write-Log "Invalid choice. Please enter Y or N." -Level 2 -Color Red
        }
    }
}

#===========================================================================
# FINALIZATION
#===========================================================================
Write-Log "-------------------------------------------------------------------------------" -Color Green
Write-Log "Installation of ComfyUI and all nodes is complete!" -Color Green
Read-Host "Press Enter to close this window."
