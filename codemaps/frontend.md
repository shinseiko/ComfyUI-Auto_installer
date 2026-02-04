# ComfyUI Auto-Installer - User Interface

**Last Updated:** 2026-02-03 20:27:20

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
4. Execute `Install-ComfyUI-Phase1.ps1`

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
- Launches `python main.py` with arguments

#### UmeAiRT-Update-ComfyUI.bat
**Purpose:** Update installation

**Flow:**
1. Activate environment
2. Execute `Update-ComfyUI.ps1`
3. Wait for completion

#### UmeAiRT-Download_models.bat
**Purpose:** Download additional models post-installation

**Flow:**
1. Activate environment
2. Present model pack menu
3. Execute selected download scripts

#### UmeAiRT-Start-ComfyUI_LowVRAM.bat
**Purpose:** Launch ComfyUI with low VRAM optimizations

**Arguments:** `--lowvram --preview-method latent2rgb`

## Console UI Elements

### Progress Indicators
\\\
===============================================
| [Step 3/9] Installing Core Dependencies |
===============================================
  - Upgrading pip and wheel
    -> Executing: python -m pip install ...
      [INFO] Successfully installed pip-24.0
\\\

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
\\\
Choose installation type:
1. Light (Recommended) - Uses your existing Python 3.13
2. Full - Installs Miniconda, Python 3.13, Git, CUDA

Enter choice (1 or 2): _
\\\

**Pattern:** `Read-Host` with validation loop

### Model Selection Menus
\\\
Your GPU: NVIDIA GeForce RTX 4090 (24 GB VRAM)

Recommended models for your configuration:

  1. FLUX.1-dev (12 GB) - Text to image
  2. FLUX.1-schnell (8 GB) - Fast text to image

Would you like to download FLUX.1-dev? (Y/N): _
\\\

**Pattern:** VRAM-aware recommendations with Y/N prompts

## Error Handling UI

### Fatal Errors
\\\
ERROR: Python 3.13 is required.
Please install it manually from python.org and restart this script.
Press Enter to exit._
\\\

### Warnings
\\\
WARNING: aria2c failed, using slower Invoke-WebRequest...
\\\

### Installation Prompts
\\\
Git is not installed.
Git is required to download ComfyUI and custom nodes.

Would you like to download and install Git automatically? (Y/N): _
\\\

## ASCII Branding
\\\
                     __  __               ___    _ ____  ______
                    / / / /___ ___  ___  /   |  (_) __ \/_  __/
                   / / / / __ \__ \/ _ \/ /| | / / /_/ / / /
                  / /_/ / / / / / /  __/ ___ |/ / _, _/ / /
                  \____/_/ /_/ /_/\___/_/  |_/_/_/ |_| /_/

              ComfyUI - Auto-Installer
                    Version 4.3
\\\

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
\\\
Downloading "flux1-dev.safetensors"
[###############################] 100% (11.5GB/11.5GB)
Download successful (aria2c).
\\\

When using PowerShell:
\\\
Downloading "model.safetensors"
[Slower download, no progress bar]
Download successful (PowerShell).
\\\

## Post-Installation Messages
\\\
===============================================================================
Installation completed successfully!

To launch ComfyUI, run:
  UmeAiRT-Start-ComfyUI.bat

To download more models:
  UmeAiRT-Download_models.bat

To update ComfyUI:
  UmeAiRT-Update-ComfyUI.bat
===============================================================================
\\\