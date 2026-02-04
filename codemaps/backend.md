# ComfyUI Auto-Installer - Backend Structure

**Last Updated:** 2026-02-03 20:27:20

## PowerShell Modules

### UmeAiRTUtils.psm1
Shared utility module with core functions:

#### Logging Functions
- `Write-Log(Message, Level, Color)` - Unified console + file logging
  - Level 0: Step headers with progress
  - Level 1: Main items
  - Level 2: Sub-items
  - Level 3: Debug info

#### Command Execution
- `Invoke-AndLog(File, Arguments, [IgnoreErrors])` - Execute external commands with logging

#### File Operations
- `Save-File(Uri, OutFile)` - Download with aria2c (fallback to Invoke-WebRequest)

#### User Interaction
- `Read-UserChoice(Prompt, Choices, ValidAnswers)` - Menu selection helper

#### System Detection
- `Test-NvidiaGpu()` - Detect NVIDIA GPU via nvidia-smi
- `Get-GpuVramInfo()` - Query GPU name and VRAM capacity
- `Test-PyVersion(Command, Arguments)` - Verify Python 3.13

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
- `\` - Root installation directory
- `\` - %LOCALAPPDATA%\Miniconda3
- `\` - "Light" (venv) or "Full" (conda)

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
1. **Primary:** snapshot.json - `cm-cli.py restore-snapshot` (version-locked install)
2. **Fallback:** custom_nodes.csv - `cm-cli.py install` per node (if snapshot missing)

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
1. GPU VRAM detection via `Get-GpuVramInfo`
2. Display recommended models based on VRAM
3. User selection menu
4. Download via `Save-File` (aria2c)
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
\\\powershell
\ = Get-Content dependencies.json | ConvertFrom-Json
\.repositories.comfyui.url
\.pip_packages.torch.packages
\\\

### custom_nodes.csv
CSV format: `Name,RepoUrl,Subfolder,RequirementsFile`

35+ custom nodes including:
- ComfyUI-Manager (node manager)
- ComfyUI-Impact-Pack (detailers)
- ComfyUI-KJNodes (utilities)
- comfyui_controlnet_aux (ControlNet)

**Processing:**
Import-Csv → Parallel git clone → Install requirements.txt

## Error Handling Strategy
- `Invoke-AndLog` throws on non-zero exit codes (unless `-IgnoreErrors`)
- Temporary log files for subprocess output
- All errors logged to `logs/install_log.txt`
- User prompts on fatal errors (`Read-Host` before exit)

## Parallel Execution
Custom nodes installation uses PowerShell jobs:
- `\ = Floor(CPU_CORES * 3/4)`
- `Start-Job` for git clones
- `Wait-Job` + `Receive-Job` for results