@echo off
setlocal
set "PYTHONPATH="
set "PYTHONNOUSERSITE=1"

:: ============================================================================
:: File: UmeAiRT-Start-ComfyUI.bat
:: Description: Launcher for ComfyUI (Performance Mode).
::              - Detects installation type (Conda vs venv)
::              - Activates environment
::              - Launches main.py with SageAttention
:: Author: UmeAiRT
:: ============================================================================

set "InstallPath=%~dp0"
if "%InstallPath:~-1%"=="\" set "InstallPath=%InstallPath:~0,-1%"

:: ----------------------------------------------------------------------------
:: Section 1: Environment Detection & Activation
:: ----------------------------------------------------------------------------
echo [INFO] Checking installation type...
set "InstallTypeFile=%InstallPath%\scripts\install_type"
set "InstallType=conda"

if exist "%InstallTypeFile%" (
    set /p InstallType=<"%InstallTypeFile%"
) else (
    :: Fallback detection
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
    :: Assuming standard Miniconda installation
    call "%LOCALAPPDATA%\Miniconda3\Scripts\activate.bat"
    call conda activate UmeAiRT
    if %errorlevel% neq 0 (
        echo [ERROR] Failed to activate Conda environment 'UmeAiRT'.
        pause
        exit /b %errorlevel%
    )
)

:: ----------------------------------------------------------------------------
:: Section 2: Launch ComfyUI
:: ----------------------------------------------------------------------------
echo [INFO] Starting ComfyUI (Performance Mode)...
cd /d "%InstallPath%\ComfyUI"

:: Launching with SageAttention and auto-launch
python main.py --use-sage-attention --listen --auto-launch

pause
