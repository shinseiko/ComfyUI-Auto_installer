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
$comfyUserPath = Join-Path $comfyPath "user"
$scriptPath = Join-Path $InstallPath "scripts"
$condaPath = Join-Path $env:LOCALAPPDATA "Miniconda3"
$condaExe = Join-Path $condaPath "Scripts\conda.exe"
$logPath = Join-Path $InstallPath "logs"
$logFile = Join-Path $logPath "install_log.txt"
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

$dependenciesFile = Join-Path (Split-Path -Path $MyInvocation.MyCommand.Definition -Parent) "dependencies.json"
if (-not (Test-Path $dependenciesFile)) { Write-Host "FATAL: dependencies.json not found..." -ForegroundColor Red; Read-Host; exit 1 }
$dependencies = Get-Content -Raw -Path $dependenciesFile | ConvertFrom-Json
if (-not (Test-Path $logPath)) { New-Item -ItemType Directory -Force -Path $logPath | Out-Null }

Import-Module (Join-Path $scriptPath "UmeAiRTUtils.psm1") -Force
$global:logFile = Join-Path $logPath "install_log.txt"
$global:hasGpu = Test-NvidiaGpu
Write-Log "DEBUG: Loaded tools config: $($dependencies.tools | ConvertTo-Json -Depth 3)" -Level 3
#===========================================================================
# SECTION 2: MAIN SCRIPT EXECUTION
#===========================================================================
$global:totalSteps = 8
$global:currentStep = 2
$totalCores = [int]$env:NUMBER_OF_PROCESSORS
$optimalParallelJobs = [int][Math]::Floor(($totalCores * 3) / 4)
if ($optimalParallelJobs -lt 1) { $optimalParallelJobs = 1 }
Write-Log "Configuring Git to handle long paths (system-wide)..." -Level 1
Invoke-AndLog "git" "config --system core.longpaths true"
# --- Step 2: Clone ComfyUI ---
Write-Log "Cloning ComfyUI" -Level 0
if (-not (Test-Path $comfyPath)) {
    Write-Log "Cloning ComfyUI repository from $($dependencies.repositories.comfyui.url)..." -Level 1
    $cloneArgs = "clone $($dependencies.repositories.comfyui.url) `"$comfyPath`""
    Invoke-AndLog "git" $cloneArgs

    if (-not (Test-Path $comfyPath)) {
        Write-Log "FATAL: ComfyUI cloning failed. Please check the logs." -Level 0 -Color Red
        Read-Host "Press Enter to exit."
        exit 1
    }
} else {
    Write-Log "ComfyUI directory already exists" -Level 1 -Color Green
}

if (-not (Test-Path $comfyUserPath)) { New-Item -ItemType Directory -Force -Path $comfyUserPath | Out-Null }

# --- Step 3: Install Core Dependencies ---
Write-Log "Installing Core Dependencies" -Level 0
Write-Log "Upgrading pip and wheel" -Level 1
Invoke-AndLog "python" "-m pip install --upgrade $($dependencies.pip_packages.upgrade -join ' ')"
Write-Log "Installing torch packages" -Level 1
Invoke-AndLog "python" "-m pip install $($dependencies.pip_packages.torch.packages) --index-url $($dependencies.pip_packages.torch.index_url)"
Write-Log "Installing ComfyUI requirements" -Level 1
Invoke-AndLog "python" "-m pip install -r `"$comfyPath\$($dependencies.pip_packages.comfyui_requirements)`""

# --- Step 4: Install Final Python Dependencies ---
Write-Log "Installing Final Python Dependencies" -Level 0
Write-Log "Installing standard packages..." -Level 1
Invoke-AndLog "python" "-m pip install $($dependencies.pip_packages.standard -join ' ')"

# --- Step 5: Install Custom Nodes ---
# --- Step 5: Install Custom Nodes & Wheels [ORDRE CORRIGÉ] ---
Write-Log "Installing Custom Nodes & Wheels" -Level 0

# [CORRIGÉ] Étape 5.1 : Installer les Wheels en premier
Write-Log "Installing packages from .whl files..." -Level 1
foreach ($wheel in $dependencies.pip_packages.wheels) {
    Write-Log "Installing $($wheel.name)" -Level 2
    
    # [CORRIGÉ] Télécharger dans le dossier des scripts pour plus de propreté
    $wheelPath = Join-Path $scriptPath "$($wheel.name).whl" 
    
    Download-File -Uri $wheel.url -OutFile $wheelPath
    
    if (Test-Path $wheelPath) {
        # Force-reinstall pour s'assurer que notre version écrase tout
        Invoke-AndLog "python" "-m pip install --force-reinstall `"$wheelPath`""
        Remove-Item $wheelPath -ErrorAction SilentlyContinue
    } else {
        Write-Log "ERROR: Failed to download wheel $($wheel.name)" -Level 2 -Color Red
    }
}

# [CORRIGÉ] Étape 5.2 : Installer les Custom Nodes
Write-Log "Installing Custom Nodes from CSV..." -Level 0
$csvPath = Join-Path $InstallPath $dependencies.files.custom_nodes_csv.destination
$customNodes = Import-Csv -Path $csvPath
$customNodesPath = Join-Path $InstallPath "custom_nodes"

foreach ($node in $customNodes) {
    $nodeName = $node.Name
    $repoUrl = $node.RepoUrl
    $nodePath = if ($node.Subfolder) { Join-Path $customNodesPath $node.Subfolder } else { Join-Path $customNodesPath $nodeName }
    
    if (-not (Test-Path $nodePath)) {
        Write-Log "Installing $nodeName" -Level 1
        Invoke-AndLog "git" "clone $repoUrl `"$nodePath`""
        
        if ($node.RequirementsFile) {
            $reqPath = Join-Path $nodePath $node.RequirementsFile
            if (Test-Path $reqPath) {
                Write-Log "Installing requirements for $nodeName" -Level 2
                # À ce stade, insightface est DÉJÀ installé depuis le wheel.
                # pip le verra et n'essaiera pas de le compiler.
                Invoke-AndLog "python" "-m pip install -r `"$reqPath`""
            }
        }
    }
    else {
        Write-Log "$nodeName (already exists, skipping)" -Level 1 -Color Green
    }
}

# [CORRIGÉ] Étape 5.3 : Installer les repos Git (xformers, apex)
# (Cette partie était déjà après les custom nodes, mais elle est maintenant 
# logiquement la dernière partie de l'étape 5)
Write-Log "Installing packages from git repositories..." -Level 1
if ($global:hasGpu) {
    Write-Log "GPU detected, installing GPU-specific repositories..." -Level 1

    foreach ($repo in $dependencies.pip_packages.git_repos) {
        Write-Log "Installing $($repo.name)..." -Level 2
        
        # --- DÉBUT DE LA LOGIQUE POUR CUDA_MINOR_VERSION_MISMATCH_OK ---
        # (C'est la correction que nous avons discutée pour apex)
        $installUrl = "git+$($repo.url)@$($repo.commit)"
        $pipArgs = "-m pip install"
        if ($repo.install_options) {
            $pipArgs += " $($repo.install_options)"
        }
        $pipArgs += " `"$installUrl`""

        $tempEnvVars = @{}
        if ($repo.PSObject.Properties.Name -contains 'env_vars') {
            foreach ($key in $repo.env_vars.PSObject.Properties.Keys) {
                $value = $repo.env_vars.$key
                Write-Log "Setting temporary env var for $($repo.name): $key=$value" -Level 3 -Color Cyan
                $env:$key = $value
                $tempEnvVars[$key] = $null
            }
        }
        
        try {
            Invoke-AndLog "python" $pipArgs
        }
        finally {
            foreach ($key in $tempEnvVars.Keys) {
                Write-Log "Cleaning up env var: $key" -Level 3
                Remove-Item "Env:\$key" -ErrorAction SilentlyContinue
            }
        }
        # --- FIN DE LA LOGIQUE POUR CUDA_MINOR_VERSION_MISMATCH_OK ---
    }

} else {
    Write-Log "Skipping GPU-specific git repositories as no GPU was found." -Level 1
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
    Invoke-AndLog "git" "clone $($workflowRepo.url) `"$workflowCloneDest`""
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
