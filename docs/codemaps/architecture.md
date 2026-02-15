<!-- Generated: 2026-02-15 | Source files: 14 | Token estimate: ~900 -->

# Architecture

## System Overview

Windows-only ComfyUI auto-installer using PowerShell scripts and batch launchers.
Two-phase install, NTFS junction-based external folder architecture, bootstrap self-update.

## Entry Points (5 bat files)

```
UmeAiRT-Install-ComfyUI.bat       → Bootstrap-Downloader.ps1 → Install-ComfyUI-Phase1.ps1 → Launch-Phase2.ps1 → Install-ComfyUI-Phase2.ps1
UmeAiRT-Update-ComfyUI.bat        → Bootstrap-Downloader.ps1 (SkipSelf) → env activation → Update-ComfyUI.ps1
UmeAiRT-Start-ComfyUI.bat         → env activation → python main.py --use-sage-attention --listen --auto-launch
UmeAiRT-Start-ComfyUI_LowVRAM.bat → env activation → python main.py --use-sage-attention --listen --auto-launch --disable-smart-memory --lowvram --fp8_e4m3fn-text-enc
UmeAiRT-Download_models.bat       → numeric menu (1-8, Q quit) via set /p → Download-{MODEL}-Models.ps1
```

## Bootstrap Self-Update

Both Install and Update bat files run `Bootstrap-Downloader.ps1` first to fetch latest
scripts/configs from GitHub. Supports fork testing via `repo-config.json` at install root
with keys `gh_user`, `gh_reponame`, `gh_branch`. Update bat passes `-SkipSelf` to avoid
file lock on its own bat file.

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
Bat files activate the appropriate environment before launching Python.
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
| `scripts/Bootstrap-Downloader.ps1` | 94 | Self-update downloader |
| `scripts/Download-FLUX-Models.ps1` | 203 | FLUX model downloader (representative) |
| `scripts/dependencies.json` | 70 | URLs, packages, tool configs |
| `scripts/environment.yml` | 18 | Conda env spec (python=3.13.11, cuda-toolkit=13.0.2) |
