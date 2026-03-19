<!-- Generated: 2026-03-18 | Source files: 18 | Token estimate: ~1100 -->

# Architecture

## System Overview

Windows-only ComfyUI auto-installer using PowerShell scripts and batch launchers.
Two-phase install, NTFS junction-based external folder architecture, bootstrap self-update.

## Entry Points (5 bat files)

```
UmeAiRT-Install-ComfyUI.bat       → reads umeairt-user-config.json → Bootstrap-Downloader.ps1 → Install-ComfyUI-Phase1.ps1 → Launch-Phase2.ps1 → Install-ComfyUI-Phase2.ps1
UmeAiRT-Update-ComfyUI.bat        → reads umeairt-user-config.json → Bootstrap-Downloader.ps1 (SkipSelf) → env activation → Update-ComfyUI.ps1
UmeAiRT-Start-ComfyUI.bat         → calls scripts/Start-ComfyUI.ps1 (thin wrapper)
UmeAiRT-Start-ComfyUI_LowVRAM.bat → calls scripts/Start-ComfyUI.ps1 -LowVRAM (thin wrapper)
UmeAiRT-Download_models.bat       → numeric menu (1-8, Q quit) via set /p → Download-{MODEL}-Models.ps1
```

## Bootstrap Self-Update

Install and Update bat files read `umeairt-user-config.json` (preferred) or fall back to
`repo-config.json` (deprecated) for fork testing. Both config files support keys:
`gh_user`, `gh_reponame`, `gh_branch`. Input validation happens before URL interpolation.
Update bat passes `-SkipSelf` to avoid file lock on its own bat file.

## Two-Phase Installation

**Phase 1** (`Install-ComfyUI-Phase1.ps1`, 523 lines):
- Admin tasks via UAC self-elevation: Long Paths registry key, VS Build Tools install
- Install type selection: `Read-Host` with numeric `1`/`2` choices (Light=venv, Full=Conda)
- System deps: aria2 (download accelerator), Git (auto-install prompt Y/N), Python 3.13 or Miniconda
- Creates environment: venv (`python -m venv`) or Conda (`conda env create -f environment.yml`)
- Generates `Launch-Phase2.ps1` dynamically (env-specific activation + Phase2 call)
- Launches Phase 2 in a new PowerShell window

**Phase 2** (`Install-ComfyUI-Phase2.ps1`, 510 lines):
- Clones ComfyUI from `dependencies.repositories.comfyui.url`
- Sets up junction architecture (5 folders)
- Pip installs: ninja, pip/wheel upgrade, torch+cu130, ComfyUI requirements, standard packages
- Custom nodes via `cm-cli.py`: snapshot.json (primary) or custom_nodes.csv (fallback)
- UmeAiRT-Sync custom node (workflow auto-update)
- MagCache hotfix: patches line 13 of `nodes.py` and `nodes_calibration.py`
- Triton/SageAttention: DazzleML installer (venv) or manual pip (Conda fallback)
- Nunchaku config download, ComfyUI settings download
- .whl installs: nunchaku, insightface
- Optional model packs: Y/N `Read-Host` per pack (8 packs)

## ComfyUI Launch Flow (`Start-ComfyUI.ps1`, 214 lines)

Unified launcher for both standard and low-VRAM modes. Replaces hardcoded launch logic
in old bat files with parameterized PowerShell script.

**Execution flow:**
1. Detect install type (venv or conda) from `scripts/install_type` file or directory presence
2. Activate appropriate Python environment (venv Activate.ps1 or conda)
3. Read `umeairt-user-config.json` if present for network config
4. Validate config: gh_user/gh_reponame/gh_branch (alphanumeric + hyphens/underscores)
5. Validate network config: listen_enabled flag, listen_address (IPv4/IPv6), listen_port (1-65535)
6. Build network args: `--listen <address>` + optional `--port` (only if not default 8188)
7. Build VRAM args: if -LowVRAM flag, add `--disable-smart-memory --lowvram --fp8_e4m3fn-text-enc`
8. Launch: `python main.py --use-sage-attention --auto-launch <network-args> <vram-args>`

**Security:** listen_address validation prevents IP injection; warns if exposing 0.0.0.0 or ::

## Junction Architecture

ComfyUI internal folders are NTFS junctions to external folders at install root.
Enables clean `git pull` updates without overwriting user data.

```
InstallRoot/
├── ComfyUI/                 (git clone)
│   ├── custom_nodes/  →  junction → InstallRoot/custom_nodes/
│   ├── models/        →  junction → InstallRoot/models/
│   ├── output/        →  junction → InstallRoot/output/
│   ├── input/         →  junction → InstallRoot/input/
│   └── user/          →  junction → InstallRoot/user/
├── scripts/                 (PowerShell scripts, configs, venv if Light install)
├── logs/
└── *.bat                    (5 launchers)
```

## Environment Detection

All scripts detect install type via `scripts/install_type` file content ("venv" or "conda").
Fallback: check for `scripts/venv/` directory existence.
Bat files use `where pwsh` to prefer PowerShell 7+ over Windows PowerShell 5.1.
PS1 scripts resolve `$pythonExe` based on install type.

## Update Flow (`Update-ComfyUI.ps1`, 171 lines)

1. `git pull` ComfyUI core + reinstall requirements.txt
2. Update ComfyUI-Manager (git pull + reinstall requirements)
3. `cm-cli.py restore-snapshot` (install any missing nodes from snapshot)
4. `cm-cli.py update all` (update all existing nodes)
5. DazzleML installer `--upgrade` (Triton/SageAttention)

## Key Files

| File | Lines | Purpose |
|------|-------|---------|
| `scripts/UmeAiRTUtils.psm1` | 352 | Shared utility module (7 exported functions) |
| `scripts/Install-ComfyUI-Phase1.ps1` | 523 | Admin setup + environment creation |
| `scripts/Install-ComfyUI-Phase2.ps1` | 510 | ComfyUI clone + deps + nodes + models |
| `scripts/Update-ComfyUI.ps1` | 171 | Updater (git pull + cm-cli + DazzleML) |
| `scripts/Start-ComfyUI.ps1` | 214 | ComfyUI launcher (env detection + network config) |
| `scripts/Bootstrap-Downloader.ps1` | 94 | Self-update downloader |
| `scripts/Download-FLUX-Models.ps1` | 203 | FLUX model downloader (representative) |
| `scripts/dependencies.json` | 70 | URLs, packages, tool configs |
| `scripts/environment.yml` | 18 | Conda env spec (python=3.13.11, cuda-toolkit=13.0.2) |
| `scripts/umeairt-user-config.json.example` | 37 | Template for user-local config (preferred) |
| `repo-config.json.example` | 10 | Deprecated template (fallback only) |
