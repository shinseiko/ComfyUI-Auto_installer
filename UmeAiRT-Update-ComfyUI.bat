@echo off
setlocal

:: ============================================================================
:: Section 1: Bootstrap downloader for all scripts
:: ============================================================================
title UmeAiRT ComfyUI Updater
echo.
:: Create a "clean" path variable without the trailing backslash
set "InstallPath=%~dp0"
if "%InstallPath:~-1%"=="\" set "InstallPath=%InstallPath:~0,-1%"

set "ScriptsFolder=%InstallPath%\scripts"
set "BootstrapScript=%ScriptsFolder%\Bootstrap-Downloader.ps1"
set "BootstrapUrl=https://github.com/UmeAiRT/ComfyUI-Auto_installer/raw/main/scripts/Bootstrap-Downloader.ps1"

:: (Le reste de la Section 1 reste identique...)
:: ...
echo [INFO] Running the bootstrap script to update all required files...
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%BootstrapScript%" -InstallPath "%InstallPath%" -Mode "Update"
echo [OK] All scripts are now up-to-date.
echo.

:: ============================================================================
:: Section 2: Running the main update script (Activation de Conda)
:: ============================================================================
echo [INFO] Launching the main update script...
echo.

:: 1. Trouver Conda
set "CondaPath=%LOCALAPPDATA%\Miniconda3"
set "CondaActivate=%CondaPath%\Scripts\activate.bat"

if not exist "%CondaActivate%" (
    echo [ERREUR] Impossible de trouver Conda à l'adresse : %CondaActivate%
    echo L'environnement ne peut pas être activé.
    pause
    goto :eof
)

echo [INFO] Activation de l'environnement Conda 'UmeAiRT'...
:: 2. Activer l'environnement
call "%CondaActivate%" UmeAiRT
if %errorlevel% neq 0 (
    echo [ERREUR] Échec de l'activation de l'environnement Conda 'UmeAiRT'.
    pause
    goto :eof
)

echo [INFO] Lancement du script de mise à jour PowerShell...
:: 3. Exécuter le script de mise à jour
powershell.exe -ExecutionPolicy Bypass -File "%ScriptsFolder%\Update-ComfyUI.ps1" -InstallPath "%InstallPath%"

echo.
echo [INFO] The update script is complete.
pause

:: ============================================================================
:: Section 3: Self-Update (CORRIGÉ AVEC UN ASSISTANT EXTERNE)
:: ============================================================================
echo [INFO] Checking for updater self-update...
if exist "%InstallPath%\UmeAiRT-Update-ComfyUI.bat.new" (
    echo [INFO] A new version of the updater was found.
    echo [INFO] This window will close, and a new window will open to complete the update.

    :: Créer le script assistant temporaire
    set "FinisherScript=%InstallPath%\_update_finisher.bat"
    (
        echo @echo off
        echo title Updater Finisher
        echo echo Waiting for main script to release files...
        echo ping 127.0.0.1 -n 3 > nul
        echo echo Applying update...
        echo move /Y "%InstallPath%\UmeAiRT-Update-ComfyUI.bat.new" "%InstallPath%\UmeAiRT-Update-ComfyUI.bat"
        echo echo Update applied. This window will self-destruct.
        echo ping 127.0.0.1 -n 2 > nul
        echo del "%FinisherScript%"
        echo exit
    ) > "%FinisherScript%"

    :: Lancer l'assistant dans une NOUVELLE fenêtre
    start "Updater Finisher" cmd /C "%FinisherScript%"
    
    :: Quitter ce script IMMÉDIATEMENT pour libérer le fichier
    goto :eof
)

endlocal