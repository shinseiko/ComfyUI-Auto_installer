param(
    [string]$InstallPath,
    [switch]$SkipSelf = $false
)

# Set the base URL for the GitHub repository's raw content
$baseUrl = "https://github.com/UmeAiRT/ComfyUI-Auto_installer/raw/feature-conda-integration/"

# Define the list of files to download
$filesToDownload = @(
    # PowerShell Scripts
    @{ RepoPath = "scripts/Install-ComfyUI-Phase1.ps1";  LocalPath = "scripts/Install-ComfyUI-Phase1.ps1" },
    @{ RepoPath = "scripts/Install-ComfyUI-Phase2.ps1";  LocalPath = "scripts/Install-ComfyUI-Phase2.ps1" },
    @{ RepoPath = "scripts/Update-ComfyUI.ps1";          LocalPath = "scripts/Update-ComfyUI.ps1" },
    @{ RepoPath = "scripts/Download-FLUX-Models.ps1";    LocalPath = "scripts/Download-FLUX-Models.ps1" },
    @{ RepoPath = "scripts/Download-WAN2.1-Models.ps1";  LocalPath = "scripts/Download-WAN2.1-Models.ps1" },
    @{ RepoPath = "scripts/Download-WAN2.2-Models.ps1";  LocalPath = "scripts/Download-WAN2.2-Models.ps1" },
    @{ RepoPath = "scripts/Download-HIDREAM-Models.ps1"; LocalPath = "scripts/Download-HIDREAM-Models.ps1" },
    @{ RepoPath = "scripts/Download-LTXV-Models.ps1";    LocalPath = "scripts/Download-LTXV-Models.ps1" },
    @{ RepoPath = "scripts/Download-QWEN-Models.ps1";    LocalPath = "scripts/Download-QWEN-Models.ps1" },
    @{ RepoPath = "scripts/UmeAiRTUtils.psm1";           LocalPath = "scripts/UmeAiRTUtils.psm1" },
    # Configuration Files
    @{ RepoPath = "scripts/environment.yml";             LocalPath = "scripts/environment.yml" },
    @{ RepoPath = "scripts/dependencies.json";           LocalPath = "scripts/dependencies.json" },
    @{ RepoPath = "scripts/custom_nodes.csv";            LocalPath = "scripts/custom_nodes.csv" },
    # Batch Launchers
    @{ RepoPath = "UmeAiRT-Start-ComfyUI.bat";           LocalPath = "UmeAiRT-Start-ComfyUI.bat" },
    @{ RepoPath = "UmeAiRT-Download_models.bat";         LocalPath = "UmeAiRT-Download_models.bat" },
    @{ RepoPath = "UmeAiRT-Update-ComfyUI.bat";          LocalPath = "UmeAiRT-Update-ComfyUI.bat" }
)

Write-Host "[INFO] Downloading the latest versions of the installation scripts..."
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

foreach ($file in $filesToDownload) {

    # Logique pour ignorer l'auto-mise à jour
    if ($SkipSelf -and $file.LocalPath -eq "UmeAiRT-Update-ComfyUI.bat") {
        Write-Host "  - Skipping download of UmeAiRT-Update-ComfyUI.bat (self-update disabled)" -Color Gray
        continue # Passe au fichier suivant
    }

    $uri = $baseUrl + $file.RepoPath
    $outFile = Join-Path $InstallPath $file.LocalPath

    $outDir = Split-Path -Path $outFile -Parent
    if (-not (Test-Path $outDir)) {
        New-Item -ItemType Directory -Path $outDir -Force | Out-Null
    }

    # Paramètres pour Invoke-WebRequest
    $invokeArgs = @{ Uri = $uri; OutFile = $outFile; ErrorAction = 'Stop' }
    
    # ==================== DÉBUT DE LA CORRECTION ====================
    # Les fichiers .bat DOIVENT être en ANSI (Default) pour cmd.exe
    if ($outFile -like "*.bat") {
        Write-Host "  - Downloading $($file.RepoPath) (as .bat -> ANSI)..."
        $invokeArgs.Encoding = 'Default' 
    } else {
    # Les autres fichiers (.ps1, .json, .yml) sont OK en UTF-8 (avec BOM, compatible PS 5.1)
        Write-Host "  - Downloading $($file.RepoPath)..."
        $invokeArgs.Encoding = 'utf8' 
    }
    # ==================== FIN DE LA CORRECTION ====================
    
    try {
        Invoke-WebRequest @invokeArgs
    } catch {
        Write-Host "[ERROR] Failed to download '$($file.RepoPath)'." -ForegroundColor Red
        Read-Host "Press Enter to exit."
        exit 1
    }
}

Write-Host "[OK] All required files have been downloaded successfully." -ForegroundColor Green