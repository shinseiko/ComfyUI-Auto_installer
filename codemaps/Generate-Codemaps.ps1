<#
.SYNOPSIS
    Generates architecture documentation (codemaps) for the ComfyUI Auto-Installer.
.DESCRIPTION
    Analyzes PowerShell scripts, JSON configs, and CSV files to produce
    token-lean architectural documentation.
#>

param(
    [string]$RootPath = (Split-Path -Parent $PSScriptRoot),
    [string]$OutputDir = $PSScriptRoot,
    [string]$ReportDir = (Join-Path (Split-Path -Parent $PSScriptRoot) ".reports")
)

# Create output directories
if (-not (Test-Path $OutputDir)) { New-Item -ItemType Directory -Path $OutputDir -Force | Out-Null }
if (-not (Test-Path $ReportDir)) { New-Item -ItemType Directory -Path $ReportDir -Force | Out-Null }

$timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"

# ============================================================================
# ARCHITECTURE CODEMAP
# ============================================================================

$archContent = @"
# ComfyUI Auto-Installer - Architecture Overview

**Last Updated:** $timestamp

## Project Type
Windows PowerShell automation installer for ComfyUI (AI image generation UI)

## Core Purpose
Automated installation and configuration of ComfyUI with custom nodes, models, and dependencies on Windows 10/11.

## Technology Stack
- **Scripting:** PowerShell 5.1+
- **Package Management:** Miniconda/Anaconda, pip
- **Dependencies:** Python 3.13, Git, Aria2, 7-Zip
- **Target Platform:** Windows 10/11 (64-bit), CUDA 13.0

## Architecture Pattern
Two-phase installer with external folder architecture:

### Phase 1 (Admin Setup)
- Privilege elevation & system prerequisites
- Python/Miniconda installation
- Environment creation (venv or Conda)

### Phase 2 (User Environment)
- ComfyUI cloning and setup
- Dependency installation (PyTorch, custom packages)
- Custom nodes installation via ComfyUI-Manager
- Optional model downloads

## Key Components

### Launcher Scripts (.bat)
- ``UmeAiRT-Install-ComfyUI.bat`` - Main installer entry point
- ``UmeAiRT-Start-ComfyUI.bat`` - Application launcher
- ``UmeAiRT-Update-ComfyUI.bat`` - Update orchestrator
- ``UmeAiRT-Download_models.bat`` - Model downloader menu

### Core PowerShell Scripts
- ``Install-ComfyUI-Phase1.ps1`` - System setup and environment creation
- ``Install-ComfyUI-Phase2.ps1`` - ComfyUI installation and configuration
- ``Update-ComfyUI.ps1`` - Updates ComfyUI, nodes, and workflows
- ``UmeAiRTUtils.psm1`` - Shared utility functions module

### Model Download Scripts
- ``Download-FLUX-Models.ps1`` - FLUX model downloader
- ``Download-WAN2.1-Models.ps1`` / ``Download-WAN2.2-Models.ps1`` - WAN models
- ``Download-LTX1-Models.ps1`` / ``Download-LTX2-Models.ps1`` - LTX models
- ``Download-HIDREAM-Models.ps1`` - HIDREAM models
- ``Download-QWEN-Models.ps1`` - QWEN models
- ``Download-Z-IMAGES-Models.ps1`` - Image models
- ``Bootstrap-Downloader.ps1`` - Bootstrapping helper

### Configuration Files
- ``dependencies.json`` - All dependencies, URLs, and package definitions
- ``custom_nodes.csv`` - Custom nodes repository list with requirements
- ``snapshot.json`` - ComfyUI-Manager snapshot for version locking
- ``nunchaku_versions.json`` - Nunchaku version configurations
- ``comfy.settings.json`` - Default ComfyUI settings
- ``environment.yml`` - Conda environment specification

## External Folder Architecture
Junction-based architecture separating ComfyUI core from user data:

\`\`\`
/InstallPath/
├── ComfyUI/          (git clone, core application)
│   ├── models/       -> Junction to ../models
│   ├── custom_nodes/ -> Junction to ../custom_nodes
│   ├── input/        -> Junction to ../input
│   ├── output/       -> Junction to ../output
│   └── user/         -> Junction to ../user
├── models/           (external, persists across updates)
├── custom_nodes/     (external, persists across updates)
├── input/            (external)
├── output/           (external)
├── user/             (external, settings)
├── scripts/          (installer scripts)
└── logs/             (installation logs)
\`\`\`

## Installation Modes

### Light Mode (venv)
- Uses system Python 3.13
- Creates virtual environment in ``scripts/venv``
- Faster, smaller footprint

### Full Mode (Miniconda)
- Installs Miniconda3 to %LOCALAPPDATA%
- Creates isolated 'UmeAiRT' Conda environment
- Includes CUDA toolkit and additional tools

## Dependency Management Strategy
1. PyTorch 2.10.0+cu130 from official wheels
2. Pre-built wheels for complex packages (nunchaku, insightface)
3. Custom nodes via ComfyUI-Manager CLI
4. Models via aria2c (multi-threaded downloads)

## Update Strategy
Git-based updates with dependency reconciliation:
- Pull latest ComfyUI commits
- Update all custom nodes (parallel git pulls)
- Reinstall/update Python requirements
- Preserve user data (external folders)
"@

[System.IO.File]::WriteAllText((Join-Path $OutputDir "architecture.md"), $archContent, (New-Object System.Text.UTF8Encoding $true))

# ============================================================================
# BACKEND CODEMAP (PowerShell Scripts)
# ============================================================================

$backendContent = @"
# ComfyUI Auto-Installer - Backend Structure

**Last Updated:** $timestamp

## PowerShell Modules

### UmeAiRTUtils.psm1
Shared utility module with core functions:

#### Logging Functions
- ``Write-Log(Message, Level, Color)`` - Unified console + file logging
  - Level 0: Step headers with progress
  - Level 1: Main items
  - Level 2: Sub-items
  - Level 3: Debug info

#### Command Execution
- ``Invoke-AndLog(File, Arguments, [IgnoreErrors])`` - Execute external commands with logging

#### File Operations
- ``Save-File(Uri, OutFile)`` - Download with aria2c (fallback to Invoke-WebRequest)

#### User Interaction
- ``Read-UserChoice(Prompt, Choices, ValidAnswers)`` - Menu selection helper

#### System Detection
- ``Test-NvidiaGpu()`` - Detect NVIDIA GPU via nvidia-smi
- ``Get-GpuVramInfo()`` - Query GPU name and VRAM capacity
- ``Test-PyVersion(Command, Arguments)`` - Verify Python 3.13

## Installation Scripts

### Install-ComfyUI-Phase1.ps1
**Purpose:** System prerequisites and environment setup

**Flow:**
1. Check admin requirements (Long Paths, VS Build Tools)
2. Elevate if needed (separate admin process)
3. Install system tools:
   - Git for Windows (silent install)
   - Aria2 download accelerator
   - Python 3.13 or Miniconda3
4. Create environment (venv or Conda)
5. Generate Phase 2 launcher script
6. Launch Phase 2

**Key Variables:**
- ``\$InstallPath`` - Root installation directory
- ``\$condaPath`` - %LOCALAPPDATA%\Miniconda3
- ``\$installType`` - "Light" (venv) or "Full" (conda)

### Install-ComfyUI-Phase2.ps1
**Purpose:** ComfyUI installation and configuration (runs in activated environment)

**Flow:**
1. UTF-8 encoding configuration (CJK support)
2. Git long paths configuration
3. Clone ComfyUI repository
4. Setup external folder architecture (junctions)
5. Install Python dependencies:
   - Upgrade pip/wheel
   - PyTorch + xformers
   - ComfyUI requirements.txt
   - Pre-built wheels (nunchaku, insightface)
   - Standard packages (cupy, onnxruntime-gpu, etc.)
6. Install custom nodes via ComfyUI-Manager
7. Install Triton + SageAttention (DazzleML script)
8. Download optional models (user prompts)
9. Download workflows
10. Create launcher scripts

**Custom Nodes Installation:**
Uses ComfyUI-Manager CLI with priority order:
1. **Primary:** snapshot.json - ``cm-cli.py restore-snapshot`` (version-locked install)
2. **Fallback:** custom_nodes.csv - ``cm-cli.py install`` per node (if snapshot missing)

**Model Download Integration:**
Interactive menu calling specialized download scripts

### Update-ComfyUI.ps1
**Purpose:** Update existing installation

**Flow:**
1. Detect installation type (venv/conda)
2. Activate environment
3. Update ComfyUI core (git pull)
4. Update custom nodes (parallel git pulls)
5. Reinstall dependencies
6. Update workflows
7. Optional model updates

## Model Download Scripts

### Pattern (All Download-*-Models.ps1)
1. GPU VRAM detection via ``Get-GpuVramInfo``
2. Display recommended models based on VRAM
3. User selection menu
4. Download via ``Save-File`` (aria2c)
5. Place in correct model subdirectory

### Download-FLUX-Models.ps1
Downloads FLUX text-to-image models:
- Checkpoints (unet, vae, clip)
- LoRAs
- Upscale models

### Download-LTX1-Models.ps1 / Download-LTX2-Models.ps1
Downloads LTX video generation models (Lightricks)

### Download-WAN2.1-Models.ps1 / Download-WAN2.2-Models.ps1
Downloads Wanx video models

### Download-HIDREAM-Models.ps1
Downloads HIDREAM models

### Bootstrap-Downloader.ps1
Helper for downloading initial dependencies

## Configuration Processing

### dependencies.json
Structured JSON defining:
- Repository URLs (ComfyUI, workflows)
- Tool download URLs (VS Build Tools, Miniconda)
- PyTorch packages and index URL
- Pre-built wheels (nunchaku, insightface)
- Standard pip packages
- File downloads (settings, CSV)

**Access Pattern:**
\`\`\`powershell
\$dependencies = Get-Content dependencies.json | ConvertFrom-Json
\$deps.repositories.comfyui.url
\$deps.pip_packages.torch.packages
\`\`\`

### custom_nodes.csv
CSV format: ``Name,RepoUrl,Subfolder,RequirementsFile``

35+ custom nodes including:
- ComfyUI-Manager (node manager)
- ComfyUI-Impact-Pack (detailers)
- ComfyUI-KJNodes (utilities)
- comfyui_controlnet_aux (ControlNet)

**Processing:**
Import-Csv → Parallel git clone → Install requirements.txt

## Error Handling Strategy
- ``Invoke-AndLog`` throws on non-zero exit codes (unless ``-IgnoreErrors``)
- Temporary log files for subprocess output
- All errors logged to ``logs/install_log.txt``
- User prompts on fatal errors (``Read-Host`` before exit)

## Parallel Execution
Custom nodes installation uses PowerShell jobs:
- ``\$optimalParallelJobs = Floor(CPU_CORES * 3/4)``
- ``Start-Job`` for git clones
- ``Wait-Job`` + ``Receive-Job`` for results
"@

[System.IO.File]::WriteAllText((Join-Path $OutputDir "backend.md"), $backendContent, (New-Object System.Text.UTF8Encoding $true))

# ============================================================================
# DATA CODEMAP
# ============================================================================

$dataContent = @"
# ComfyUI Auto-Installer - Data Models

**Last Updated:** $timestamp

## Configuration Files

### dependencies.json
**Location:** ``scripts/dependencies.json``

**Schema:**
\`\`\`json
{
  "repositories": {
    "comfyui": { "url": "..." },
    "workflows": { "url": "..." }
  },
  "tools": {
    "vs_build_tools": {
      "install_path": "...",
      "url": "...",
      "arguments": "..."
    },
    "miniconda": { "url": "..." }
  },
  "pip_packages": {
    "upgrade": ["pip", "wheel"],
    "torch": {
      "packages": "torch==2.10.0+cu130 ...",
      "index_url": "..."
    },
    "comfyui_requirements": "requirements.txt",
    "wheels": [
      { "name": "...", "url": "..." }
    ],
    "standard": ["package1", "package2", ...],
    "git_repos": []
  },
  "files": {
    "comfy_settings": { "url": "...", "destination": "..." },
    "custom_nodes_csv": { "url": "...", "destination": "..." },
    "installer_script": { "url": "...", "destination": "..." }
  }
}
\`\`\`

### custom_nodes.csv
**Location:** ``scripts/custom_nodes.csv``

**Purpose:** Fallback method for custom nodes installation (used if snapshot.json is missing)

**Schema:**
\`\`\`
Name,RepoUrl,Subfolder,RequirementsFile
ComfyUI-Manager,https://github.com/ltdrdata/ComfyUI-Manager.git,,
ComfyUI-Impact-Pack,https://github.com/ltdrdata/ComfyUI-Impact-Pack.git,,requirements.txt
\`\`\`

**Fields:**
- ``Name`` - Node package name
- ``RepoUrl`` - Git repository URL
- ``Subfolder`` - Optional subdirectory for nested installs
- ``RequirementsFile`` - Python requirements file (if present)

**Total Nodes:** 35+

### snapshot.json
**Location:** ``scripts/snapshot.json``

**Purpose:** Primary method for custom nodes installation - ComfyUI-Manager version snapshot for reproducible builds (version-locked)

**Schema:**
\`\`\`json
{
  "git_hash": "...",
  "custom_nodes": [
    {
      "url": "...",
      "hash": "...",
      "disabled": false
    }
  ]
}
\`\`\`

### environment.yml
**Location:** ``scripts/environment.yml``

**Purpose:** Conda environment specification for Full installation mode

**Schema:**
\`\`\`yaml
name: UmeAiRT
channels:
  - conda-forge
  - defaults
dependencies:
  - python=3.13
  - git
  - cudatoolkit=13.0
  - pip
\`\`\`

### nunchaku_versions.json
**Location:** ``scripts/nunchaku_versions.json``

**Purpose:** Version mappings for nunchaku wheel selection

### comfy.settings.json
**Location:** ``scripts/comfy.settings.json``
**Destination:** ``user/default/comfy.settings.json``

**Purpose:** Default ComfyUI UI settings (themes, shortcuts, preferences)

## Runtime Data

### install_type
**Location:** ``scripts/install_type``
**Content:** ``"venv"`` or ``"conda"``
**Purpose:** Persists installation mode for launchers and updates

### Logs
**Location:** ``logs/install_log.txt``
**Format:** ``[YYYY-MM-DD HH:MM:SS] [LEVEL] Message``

## External Data Directories

### models/
Model subdirectory structure:
\`\`\`
models/
├── checkpoints/       (SD/FLUX checkpoints)
├── clip/              (CLIP models)
├── clip_vision/       (CLIP vision encoders)
├── controlnet/        (ControlNet models)
├── diffusion_models/  (Diffusion transformers)
├── embeddings/        (Textual inversions)
├── loras/             (LoRA adapters)
├── upscale_models/    (ESRGAN, RealESRGAN)
├── vae/               (VAE models)
└── [model-specific]/  (LTX, WAN, etc.)
\`\`\`

### custom_nodes/
Cloned git repositories (one per node)

### input/
User input images/videos

### output/
Generated images/videos

### user/
User settings and workflows

## Model Download Metadata

Model scripts define metadata:
\`\`\`powershell
\$models = @(
    @{
        Name = "FLUX.1-dev"
        Url = "https://..."
        FileName = "flux1-dev.safetensors"
        Destination = "checkpoints"
        MinVRAM = 12
        Recommended = @(12, 16, 24)
    }
)
\`\`\`

**Fields:**
- ``Name`` - Display name
- ``Url`` - Download URL
- ``FileName`` - Target filename
- ``Destination`` - Model subdirectory
- ``MinVRAM`` - Minimum VRAM (GB)
- ``Recommended`` - VRAM tiers showing this model
"@

[System.IO.File]::WriteAllText((Join-Path $OutputDir "data.md"), $dataContent, (New-Object System.Text.UTF8Encoding $true))

# ============================================================================
# FRONTEND CODEMAP (User Interface)
# ============================================================================

$frontendContent = @"
# ComfyUI Auto-Installer - User Interface

**Last Updated:** $timestamp

## Interface Type
Command-line interface (CLI) via PowerShell console and Windows batch launchers

## User Entry Points

### Batch Launchers (.bat files)

#### UmeAiRT-Install-ComfyUI.bat
**Purpose:** Main installation entry point

**Flow:**
1. Request administrator privileges (UAC)
2. Set PowerShell execution policy (Bypass)
3. Download latest installer scripts from GitHub
4. Execute ``Install-ComfyUI-Phase1.ps1``

**User Interaction:**
- Installation mode selection (Light/Full)
- Git installation prompt
- Python installation prompt
- Model pack selection

#### UmeAiRT-Start-ComfyUI.bat
**Purpose:** Launch ComfyUI application

**Generated After Installation:**
- Light mode: Activates venv
- Full mode: Activates Conda environment
- Launches ``python main.py`` with arguments

#### UmeAiRT-Update-ComfyUI.bat
**Purpose:** Update installation

**Flow:**
1. Activate environment
2. Execute ``Update-ComfyUI.ps1``
3. Wait for completion

#### UmeAiRT-Download_models.bat
**Purpose:** Download additional models post-installation

**Flow:**
1. Activate environment
2. Present model pack menu
3. Execute selected download scripts

#### UmeAiRT-Start-ComfyUI_LowVRAM.bat
**Purpose:** Launch ComfyUI with low VRAM optimizations

**Arguments:** ``--lowvram --preview-method latent2rgb``

## Console UI Elements

### Progress Indicators
\`\`\`
===============================================
| [Step 3/9] Installing Core Dependencies |
===============================================
  - Upgrading pip and wheel
    -> Executing: python -m pip install ...
      [INFO] Successfully installed pip-24.0
\`\`\`

**Levels:**
- Level 0: Step headers (Yellow, with separators)
- Level 1: Main items (White, "  - " prefix)
- Level 2: Sub-items (White, "    -> " prefix)
- Level 3: Debug (DarkGray, "      [INFO] " prefix)

### Color Coding
- **Yellow:** Headers, warnings, prompts
- **Green:** Success messages
- **Red:** Errors, failures
- **Cyan:** Special notices
- **DarkGray:** Debug/verbose output

### Menu System
\`\`\`
Choose installation type:
1. Light (Recommended) - Uses your existing Python 3.13
2. Full - Installs Miniconda, Python 3.13, Git, CUDA

Enter choice (1 or 2): _
\`\`\`

**Pattern:** ``Read-Host`` with validation loop

### Model Selection Menus
\`\`\`
Your GPU: NVIDIA GeForce RTX 4090 (24 GB VRAM)

Recommended models for your configuration:

  1. FLUX.1-dev (12 GB) - Text to image
  2. FLUX.1-schnell (8 GB) - Fast text to image

Would you like to download FLUX.1-dev? (Y/N): _
\`\`\`

**Pattern:** VRAM-aware recommendations with Y/N prompts

## Error Handling UI

### Fatal Errors
\`\`\`
ERROR: Python 3.13 is required.
Please install it manually from python.org and restart this script.
Press Enter to exit._
\`\`\`

### Warnings
\`\`\`
WARNING: aria2c failed, using slower Invoke-WebRequest...
\`\`\`

### Installation Prompts
\`\`\`
Git is not installed.
Git is required to download ComfyUI and custom nodes.

Would you like to download and install Git automatically? (Y/N): _
\`\`\`

## ASCII Branding
\`\`\`
                     __  __               ___    _ ____  ______
                    / / / /___ ___  ___  /   |  (_) __ \/_  __/
                   / / / / __ \`__ \/ _ \/ /| | / / /_/ / / /
                  / /_/ / / / / / /  __/ ___ |/ / _, _/ / /
                  \____/_/ /_/ /_/\___/_/  |_/_/_/ |_| /_/

              ComfyUI - Auto-Installer
                    Version 4.3
\`\`\`

## Multi-Window Architecture

### Window 1: Phase 1 (Admin)
- Initial setup
- Admin tasks (if needed)
- Environment creation

### Window 2: Phase 2 (User Environment)
- ComfyUI installation
- Dependency installation
- Model downloads

**Reason:** Separate windows for different execution contexts (admin vs. user environment)

## Download Progress
When using aria2c:
\`\`\`
Downloading "flux1-dev.safetensors"
[###############################] 100% (11.5GB/11.5GB)
Download successful (aria2c).
\`\`\`

When using PowerShell:
\`\`\`
Downloading "model.safetensors"
[Slower download, no progress bar]
Download successful (PowerShell).
\`\`\`

## Post-Installation Messages
\`\`\`
===============================================================================
Installation completed successfully!

To launch ComfyUI, run:
  UmeAiRT-Start-ComfyUI.bat

To download more models:
  UmeAiRT-Download_models.bat

To update ComfyUI:
  UmeAiRT-Update-ComfyUI.bat
===============================================================================
\`\`\`
"@

[System.IO.File]::WriteAllText((Join-Path $OutputDir "frontend.md"), $frontendContent, (New-Object System.Text.UTF8Encoding $true))

# ============================================================================
# GENERATE DIFF REPORT
# ============================================================================

Write-Host "`nCodemaps generated successfully:" -ForegroundColor Green
Write-Host "  - $OutputDir\architecture.md" -ForegroundColor Cyan
Write-Host "  - $OutputDir\backend.md" -ForegroundColor Cyan
Write-Host "  - $OutputDir\data.md" -ForegroundColor Cyan
Write-Host "  - $OutputDir\frontend.md" -ForegroundColor Cyan

# Since this is the first generation, diff is 100%
$diffReport = @"
# Codemap Generation Report

**Timestamp:** $timestamp

## Status
First generation - no previous codemaps to compare.

## Generated Files
- codemaps/architecture.md (NEW)
- codemaps/backend.md (NEW)
- codemaps/data.md (NEW)
- codemaps/frontend.md (NEW)

## Change Percentage
100% (initial creation)

## Summary
Complete architecture documentation generated for ComfyUI Auto-Installer.
This is a PowerShell-based Windows installer project with two-phase installation
and external folder architecture for persistent user data.

## Next Steps
Run this script again after significant codebase changes to track architectural evolution.
"@

[System.IO.File]::WriteAllText((Join-Path $ReportDir "codemap-diff.txt"), $diffReport, (New-Object System.Text.UTF8Encoding $true))

Write-Host "`nDiff report: $ReportDir\codemap-diff.txt" -ForegroundColor Green
Write-Host "`nCodemap generation complete!" -ForegroundColor Yellow
