# ComfyUI Auto-Installer - Architecture Overview

**Last Updated:** 2026-02-03 20:27:20

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
- `UmeAiRT-Install-ComfyUI.bat` - Main installer entry point
- `UmeAiRT-Start-ComfyUI.bat` - Application launcher
- `UmeAiRT-Update-ComfyUI.bat` - Update orchestrator
- `UmeAiRT-Download_models.bat` - Model downloader menu

### Core PowerShell Scripts
- `Install-ComfyUI-Phase1.ps1` - System setup and environment creation
- `Install-ComfyUI-Phase2.ps1` - ComfyUI installation and configuration
- `Update-ComfyUI.ps1` - Updates ComfyUI, nodes, and workflows
- `UmeAiRTUtils.psm1` - Shared utility functions module

### Model Download Scripts
- `Download-FLUX-Models.ps1` - FLUX model downloader
- `Download-WAN2.1-Models.ps1` / `Download-WAN2.2-Models.ps1` - WAN models
- `Download-LTX1-Models.ps1` / `Download-LTX2-Models.ps1` - LTX models
- `Download-HIDREAM-Models.ps1` - HIDREAM models
- `Download-QWEN-Models.ps1` - QWEN models
- `Download-Z-IMAGES-Models.ps1` - Image models
- `Bootstrap-Downloader.ps1` - Bootstrapping helper

### Configuration Files
- `dependencies.json` - All dependencies, URLs, and package definitions
- `custom_nodes.csv` - Custom nodes repository list with requirements
- `snapshot.json` - ComfyUI-Manager snapshot for version locking
- `nunchaku_versions.json` - Nunchaku version configurations
- `comfy.settings.json` - Default ComfyUI settings
- `environment.yml` - Conda environment specification

## External Folder Architecture
Junction-based architecture separating ComfyUI core from user data:

\\\
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
\\\

## Installation Modes

### Light Mode (venv)
- Uses system Python 3.13
- Creates virtual environment in `scripts/venv`
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