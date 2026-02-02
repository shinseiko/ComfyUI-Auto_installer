@echo off
setlocal

:: ============================================================================
:: File: UmeAiRT-Download_models.bat
:: Description: Menu-driven interface to download various model checkpoints
::              (FLUX, WAN, HIDREAM, LTX, QWEN, Z-IMAGE, etc.) via PowerShell scripts.
:: Author: UmeAiRT
:: ============================================================================

:MENU
cls
echo =================================================
echo.
echo           UmeAiRT Model Downloader Menu
echo.
echo =================================================
echo.
echo  Choose model to download:
echo.
echo    1. FLUX Models
echo    2. WAN2.1 Models
echo    3. WAN2.2 Models
echo    4. HIDREAM Models
echo    5. LTX1 Models
echo    6. LTX2 Models
echo    7. QWEN Models
echo    8. Z-IMAGE Models
echo.
echo    Q. Quit
echo.

set /p "CHOICE=Your choice: "

if /i "%CHOICE%"=="1" goto :DOWNLOAD_FLUX
if /i "%CHOICE%"=="2" goto :DOWNLOAD_WAN2.1
if /i "%CHOICE%"=="3" goto :DOWNLOAD_WAN2.2
if /i "%CHOICE%"=="4" goto :DOWNLOAD_HIDREAM
if /i "%CHOICE%"=="5" goto :DOWNLOAD_LTX1
if /i "%CHOICE%"=="6" goto :DOWNLOAD_LTX2
if /i "%CHOICE%"=="7" goto :DOWNLOAD_QWEN
if /i "%CHOICE%"=="8" goto :DOWNLOAD_Z-IMG
if /i "%CHOICE%"=="Q" goto :EOF

echo [WARN] Invalid choice. Please try again.
pause
goto :MENU


:: ----------------------------------------------------------------------------
:: Model Selection Handlers
:: ----------------------------------------------------------------------------

:DOWNLOAD_FLUX
echo [INFO] Starting download of FLUX models...
powershell.exe -ExecutionPolicy Bypass -File "%~dp0scripts\Download-FLUX-Models.ps1" -InstallPath "%~dp0"
goto :END

:DOWNLOAD_WAN2.1
echo [INFO] Starting download of WAN 2.1 models...
powershell.exe -ExecutionPolicy Bypass -File "%~dp0scripts\Download-WAN2.1-Models.ps1" -InstallPath "%~dp0"
goto :END

:DOWNLOAD_WAN2.2
echo [INFO] Starting download of WAN 2.2 models...
powershell.exe -ExecutionPolicy Bypass -File "%~dp0scripts\Download-WAN2.2-Models.ps1" -InstallPath "%~dp0"
goto :END

:DOWNLOAD_HIDREAM
echo [INFO] Starting download of HIDREAM models...
powershell.exe -ExecutionPolicy Bypass -File "%~dp0scripts\Download-HIDREAM-Models.ps1" -InstallPath "%~dp0"
goto :END

:DOWNLOAD_LTX1
echo [INFO] Starting download of LTX1 models...
powershell.exe -ExecutionPolicy Bypass -File "%~dp0scripts\Download-LTX1-Models.ps1" -InstallPath "%~dp0"
goto :END

:DOWNLOAD_LTX2
echo [INFO] Starting download of LTX2 models...
powershell.exe -ExecutionPolicy Bypass -File "%~dp0scripts\Download-LTX2-Models.ps1" -InstallPath "%~dp0"
goto :END

:DOWNLOAD_QWEN
echo [INFO] Starting download of QWEN models...
powershell.exe -ExecutionPolicy Bypass -File "%~dp0scripts\Download-QWEN-Models.ps1" -InstallPath "%~dp0"
goto :END

:DOWNLOAD_Z-IMG
echo [INFO] Starting download of Z-IMAGE models...
powershell.exe -ExecutionPolicy Bypass -File "%~dp0scripts\Download-Z-IMAGES-Models.ps1" -InstallPath "%~dp0"
goto :END

:END
echo.
echo [INFO] The download script is complete.
pause
goto :MENU
