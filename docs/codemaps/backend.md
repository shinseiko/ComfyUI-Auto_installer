<!-- Generated: 2026-02-15 | Source: scripts/*.ps1, scripts/*.psm1 -->

# Backend Scripts

## Shared Utilities (`scripts/UmeAiRTUtils.psm1`, 352 lines)

7 exported functions used across all scripts:

### Write-Log (lines 15-75)
Dual-output logging: console (colored) + log file (timestamped).
- Level -2: raw (no prefix)
- Level 0: step header with `[Step N/M]`, yellow, `=` separators, increments `$global:currentStep`
- Level 1: `"  - "` prefix
- Level 2: `"    -> "` prefix
- Level 3: `"      [INFO] "` prefix
- Uses `$global:logFile`, `$global:currentStep`, `$global:totalSteps`

### Invoke-AndLog (lines 77-130)
Runs external commands via `Invoke-Expression`, captures output to temp file, logs it.
- On non-zero exit: logs error + throws (unless `-IgnoreErrors` switch)
- On fatal catch: `Read-Host` pause + `exit 1`
- Cleans up temp file in `finally` block

### Save-File (lines 132-201)
Downloads files with aria2c primary, Invoke-WebRequest fallback.
- Skips if file already exists (idempotent)
- aria2c path: `$env:LOCALAPPDATA\aria2\aria2c.exe` with flags `-x 16 -s 16 -k 1M`
- Fallback: `Invoke-WebRequest` with TLS 1.2/1.3

### Read-UserChoice (lines 203-236)
Interactive menu: displays prompt + choices array, loops until valid answer.
- Returns uppercase string (e.g., "A", "B", "C")
- Used by Download-*-Models.ps1 scripts for letter-based menus

### Test-NvidiaGpu (lines 238-270)
Runs `nvidia-smi -L`, returns `$true` if "GPU 0:" found in output.

### Get-GpuVramInfo (lines 272-313)
Queries `nvidia-smi --query-gpu=name,memory.total --format=csv,noheader,nounits`.
Returns `[PSCustomObject]@{ GpuName = string; VramGiB = int }` or `$null`.

### Test-PyVersion (lines 315-348)
Runs `<Command> <Arguments> --version`, returns `$true` if output matches "Python 3.13".

## Install Phase 1 (`scripts/Install-ComfyUI-Phase1.ps1`, 523 lines)

### Flow
1. Load dependencies.json, import UmeAiRTUtils
2. If `-RunAdminTasks` flag: enable Long Paths registry + install VS Build Tools, then exit
3. Otherwise: check if admin tasks needed, self-elevate via `Start-Process -Verb RunAs` if so
4. Install type menu: `Read-Host` with `"1"` (Light/venv) or `"2"` (Full/Conda)
5. Install aria2 (download accelerator) to `$env:LOCALAPPDATA\aria2\`
6. Git detection: `Get-Command "git"`, auto-install prompt if missing (Y/N via `Read-Host`)
7. **Light path**: detect Python 3.13 (`py -3.13` or `python`), auto-install if missing, create venv
8. **Full path**: install Miniconda if missing, accept TOS, remove old env, `conda env create -f environment.yml`
9. Generate `Launch-Phase2.ps1` (venv activate or conda-hook + activate)
10. Launch Phase 2 in new window via `Start-Process powershell.exe`

### Key Variables
- `$installType`: "Light" or "Full" (derived from user choice "1" or "2")
- `$pythonCommand` / `$pythonArgs`: detected Python executable (e.g., "py" + "-3.13")
- `$condaPath`: `$env:LOCALAPPDATA\Miniconda3`

## Install Phase 2 (`scripts/Install-ComfyUI-Phase2.ps1`, 510 lines)

### Flow
1. UTF-8 encoding setup (chcp 65001 + console + Python env vars)
2. Load dependencies.json, import UmeAiRTUtils, detect GPU
3. Environment detection: read `scripts/install_type` file to resolve `$pythonExe`
4. Git long paths config
5. Clone ComfyUI
6. Junction architecture: 5 folders (custom_nodes, models, output, input, user)
7. Core deps: ninja, pip/wheel upgrade, torch+cu130+xformers, ComfyUI requirements
8. Standard pip packages (facexlib, cython, onnxruntime-gpu, etc.)
9. Custom nodes: ComfyUI-Manager clone → cm-cli.py restore-snapshot or CSV fallback
10. UmeAiRT-Sync node install
11. MagCache hotfix (line 13 patch)
12. .whl installs (nunchaku, insightface)
13. Triton/SageAttention: DazzleML (venv) or manual pip (Conda)
14. Nunchaku config + ComfyUI settings download
15. Optional model packs: Y/N `Read-Host` loop for each of 8 packs

### Important: `$optimalParallelJobs`
Calculated at line 103-104 (`Floor(CPU_CORES * 3/4)`) but **never used**.
No `Start-Job` or parallel execution pattern exists in this script.
All operations are sequential.

## Update Script (`scripts/Update-ComfyUI.ps1`, 171 lines)

Sequential update: git pull core → update Manager → restore-snapshot → update all nodes → DazzleML upgrade.
Same environment detection pattern as Phase 2.

## Bootstrap Downloader (`scripts/Bootstrap-Downloader.ps1`, 94 lines)

Downloads all scripts + configs from GitHub via `Invoke-WebRequest`.
Parameters: `$InstallPath`, `$GhUser`, `$GhRepoName`, `$GhBranch`, `$SkipSelf`.
File list is hardcoded: 12 PS1 scripts + 4 config files + 4 bat launchers.

## Model Download Scripts (`scripts/Download-*-Models.ps1`)

All follow the same pattern (FLUX example, 203 lines):
1. Import UmeAiRTUtils, detect GPU via `Get-GpuVramInfo`
2. Show VRAM-based recommendations (thresholds: 30/18/16/14/12/8 GB)
3. Series of `Read-UserChoice` calls with letter-based menus (A/B/C/D...)
4. Procedural `Save-File -Uri ... -OutFile ...` calls based on choices
5. Models hosted on HuggingFace (`huggingface.co/UmeAiRT/...`)

8 model packs: FLUX, WAN2.1, WAN2.2, HIDREAM, LTX1, LTX2, QWEN, Z-IMAGE.
