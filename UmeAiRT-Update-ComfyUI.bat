@echo off
setlocal

:: ============================================================================
:: Section 1: Bootstrap downloader for all scripts
:: ============================================================================
title UmeAiRT ComfyUI Updater
echo.
set "InstallPath=%~dp0"
if "%InstallPath:~-1%"=="\" set "InstallPath=%InstallPath:~0,-1%"

set "ScriptsFolder=%InstallPath%\scripts"
set "BootstrapScript=%ScriptsFolder%\Bootstrap-Downloader.ps1"
set "BootstrapUrl=https://github.com/UmeAiRT/ComfyUI-Auto_installer/raw/main/scripts/Bootstrap-Downloader.ps1"

:: (Le reste de la Section 1 reste identique...)
:: ...
echo [INFO] Running the bootstrap script to update all required files...
:: ==================== DÉBUT DE LA MODIFICATION ====================
:: On ajoute -SkipSelf pour dire au script de ne PAS télécharger le .bat
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%BootstrapScript%" -InstallPath "%InstallPath%" -SkipSelf
:: ==================== FIN DE LA MODIFICATION ====================
echo [OK] All scripts are now up-to-date.
echo.

:: ============================================================================
:: Section 2: Running the main update script (Activation de Conda)
:: ============================================================================
echo [INFO] Launching the main update script...
echo.
set "CondaPath=%LOCALAPPDATA%\Miniconda3"
set "CondaActivate=%CondaPath%\Scripts\activate.bat"
if not exist "%CondaActivate%" (
    echo [ERREUR] Impossible de trouver Conda à l'adresse : %CondaActivate%
    pause
    goto :eof
)
echo [INFO] Activation de l'environnement Conda 'UmeAiRT'...
call "%CondaActivate%" UmeAiRT
if %errorlevel% neq 0 (
    echo [ERREUR] Échec de l'activation de l'environnement Conda 'UmeAiRT'.
    pause
    goto :eof
)
echo [INFO] Lancement du script de mise à jour PowerShell...
powershell.exe -ExecutionPolicy Bypass -File "%ScriptsFolder%\Update-ComfyUI.ps1" -InstallPath "%InstallPath%"
echo.
echo [INFO] The update script is complete.
pause

:: ============================================================================
:: SECTION 3: SUPPRIMÉE
:: ============================================================================

endlocal