@echo off
setlocal
set "PYTHONPATH="
set "PYTHONNOUSERSITE=1"
set "InstallPath=%~dp0"
if "%InstallPath:~-1%"=="\" set "InstallPath=%InstallPath:~0,-1%"

:: ================================================================
:: 1. ENVIRONMENT DETECTION & ACTIVATION
:: ================================================================
echo Checking installation type...
set "InstallTypeFile=%InstallPath%\scripts\install_type"
set "InstallType=conda"

if exist "%InstallTypeFile%" (
    set /p InstallType=<"%InstallTypeFile%"
) else (
    REM Fallback detection
    if exist "%InstallPath%\scripts\venv" (
        set "InstallType=venv"
    )
)

if "%InstallType%"=="venv" (
    echo [INFO] Activating venv environment...
    call "%InstallPath%\scripts\venv\Scripts\activate.bat"
    if %errorlevel% neq 0 (
        echo [ERROR] Failed to activate venv environment.
        pause
        exit /b %errorlevel%
    )
) else (
    echo [INFO] Activating Conda environment...
    REM Assuming standard Miniconda installation
    call "%LOCALAPPDATA%\Miniconda3\Scripts\activate.bat"
    call conda activate UmeAiRT
    if %errorlevel% neq 0 (
        echo [ERROR] Failed to activate Conda environment 'UmeAiRT'.
        pause
        exit /b %errorlevel%
    )
)

:: ================================================================
:: 2. LAUNCH COMFYUI (LOW VRAM MODE)
:: ================================================================
echo Starting ComfyUI (Low VRAM / Stability Mode)...
cd /d "%InstallPath%\ComfyUI"

REM Launching with memory optimizations for lower VRAM cards
python main.py --use-sage-attention --listen --auto-launch --disable-smart-memory --lowvram --fp8_e4m3fn-text-enc

pause