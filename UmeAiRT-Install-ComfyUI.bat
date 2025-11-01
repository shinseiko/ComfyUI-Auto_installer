@echo off
setlocal

:: ============================================================================
:: Section 1: Set Installation Path (Modified)
:: ============================================================================
title UmeAiRT ComfyUI Installer
echo.
cls
echo ============================================================================
echo           Welcome to the UmeAiRT ComfyUI Installer
echo ============================================================================
echo.

:: 1. Define the default path (the current directory)
set "DefaultPath=%~dp0"
if "%DefaultPath:~-1%"=="\" set "DefaultPath=%DefaultPath:~0,-1%"

echo Where would you like to install ComfyUI?
echo.
echo **Default path:** %DefaultPath%
echo.
echo -> Press ENTER to use the default path.
echo -> Or, enter a full path (e.g., D:\ComfyUI) and press ENTER.
echo.

:: 2. Prompt the user
set /p "InstallPath=Enter installation path: "

:: 3. If user entered nothing, use the default
if "%InstallPath%"=="" (
    set "InstallPath=%DefaultPath%"
)

:: 4. Clean up the final path (in case the user added a trailing \)
if "%InstallPath:~-1%"=="\" set "InstallPath=%InstallPath:~0,-1%"

echo.
echo [INFO] Installing to: %InstallPath%
echo Press any key to begin...
pause > nul

:: ============================================================================
:: Section 2: Bootstrap downloader for all scripts (Original logic)
:: ============================================================================

set "ScriptsFolder=%InstallPath%\scripts"
set "BootstrapScript=%ScriptsFolder%\Bootstrap-Downloader.ps1"
set "BootstrapUrl=https://github.com/UmeAiRT/ComfyUI-Auto_installer/raw/feature-conda-integration/scripts/Bootstrap-Downloader.ps1"

:: Create scripts folder if it doesn't exist
if not exist "%ScriptsFolder%" (
    echo [INFO] Creating the scripts folder: %ScriptsFolder%
    mkdir "%ScriptsFolder%"
)

:: Download the bootstrap script
echo [INFO] Downloading the bootstrap script...
powershell.exe -NoProfile -ExecutionPolicy Bypass -Command "[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12; Invoke-WebRequest -Uri '%BootstrapUrl%' -OutFile '%BootstrapScript%'"

:: Run the bootstrap script to download all other files
echo [INFO] Running the bootstrap script to download all required files...
:: Pass the clean install path to the PowerShell script.
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%BootstrapScript%" -InstallPath "%InstallPath%"
echo [OK] Bootstrap download complete.
echo.

:: ============================================================================
:: Section 3: Running the main installation script (Original logic)
:: ============================================================================
echo [INFO] Launching the main installation script...
echo.
:: Pass the clean install path to the PowerShell script.
powershell.exe -ExecutionPolicy Bypass -File "%ScriptsFolder%\Install-ComfyUI-Phase1.ps1" -InstallPath "%InstallPath%"

echo.
echo [INFO] The script execution is complete.
pause