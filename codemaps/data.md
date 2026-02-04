# ComfyUI Auto-Installer - Data Models

**Last Updated:** 2026-02-03 20:27:20

## Configuration Files

### dependencies.json
**Location:** `scripts/dependencies.json`

**Schema:**
\\\json
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
\\\

### custom_nodes.csv
**Location:** `scripts/custom_nodes.csv`

**Purpose:** Fallback method for custom nodes installation (used if snapshot.json is missing)

**Schema:**
\\\
Name,RepoUrl,Subfolder,RequirementsFile
ComfyUI-Manager,https://github.com/ltdrdata/ComfyUI-Manager.git,,
ComfyUI-Impact-Pack,https://github.com/ltdrdata/ComfyUI-Impact-Pack.git,,requirements.txt
\\\

**Fields:**
- `Name` - Node package name
- `RepoUrl` - Git repository URL
- `Subfolder` - Optional subdirectory for nested installs
- `RequirementsFile` - Python requirements file (if present)

**Total Nodes:** 35+

### snapshot.json
**Location:** `scripts/snapshot.json`

**Purpose:** Primary method for custom nodes installation - ComfyUI-Manager version snapshot for reproducible builds (version-locked)

**Schema:**
\\\json
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
\\\

### environment.yml
**Location:** `scripts/environment.yml`

**Purpose:** Conda environment specification for Full installation mode

**Schema:**
\\\yaml
name: UmeAiRT
channels:
  - conda-forge
  - defaults
dependencies:
  - python=3.13
  - git
  - cudatoolkit=13.0
  - pip
\\\

### nunchaku_versions.json
**Location:** `scripts/nunchaku_versions.json`

**Purpose:** Version mappings for nunchaku wheel selection

### comfy.settings.json
**Location:** `scripts/comfy.settings.json`
**Destination:** `user/default/comfy.settings.json`

**Purpose:** Default ComfyUI UI settings (themes, shortcuts, preferences)

## Runtime Data

### install_type
**Location:** `scripts/install_type`
**Content:** `"venv"` or `"conda"`
**Purpose:** Persists installation mode for launchers and updates

### Logs
**Location:** `logs/install_log.txt`
**Format:** `[YYYY-MM-DD HH:MM:SS] [LEVEL] Message`

## External Data Directories

### models/
Model subdirectory structure:
\\\
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
\\\

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
\\\powershell
\ = @(
    @{
        Name = "FLUX.1-dev"
        Url = "https://..."
        FileName = "flux1-dev.safetensors"
        Destination = "checkpoints"
        MinVRAM = 12
        Recommended = @(12, 16, 24)
    }
)
\\\

**Fields:**
- `Name` - Display name
- `Url` - Download URL
- `FileName` - Target filename
- `Destination` - Model subdirectory
- `MinVRAM` - Minimum VRAM (GB)
- `Recommended` - VRAM tiers showing this model