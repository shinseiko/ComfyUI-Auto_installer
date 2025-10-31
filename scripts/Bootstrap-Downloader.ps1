param(
    [string]$InstallPath,
    [string]$Mode = "Install" # Mode par défaut si non spécifié (pour l'installeur)
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

# Set TLS protocol for compatibility
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

foreach ($file in $filesToDownload) {
    $uri = $baseUrl + $file.RepoPath
    $outFile = Join-Path $InstallPath $file.LocalPath

    # Ensure the destination directory exists before downloading
    $outDir = Split-Path -Path $outFile -Parent
    if (-not (Test-Path $outDir)) {
        New-Item -ItemType Directory -Path $outDir -Force | Out-Null
    }

    # ==================== DÉBUT DE LA MODIFICATION ====================
    # Si on est en mode "Update" ET qu'on s'apprête à écraser le script qui nous a lancé...
    if ($file.LocalPath -eq "UmeAiRT-Update-ComfyUI.bat" -and $Mode -eq "Update") {
        # ...on télécharge sous un nom temporaire pour éviter le conflit.
        $outFile = Join-Path $InstallPath "UmeAiRT-Update-ComfyUI.bat.new"
        Write-Host "  - Downloading $($file.RepoPath) (as .new to prevent conflict)..."
    } else {
        # ...sinon (mode Install ou autre fichier), on télécharge normalement.
        Write-Host "  - Downloading $($file.RepoPath)..."
    }
    # ==================== FIN DE LA MODIFICATION ====================
    
    try {
        Invoke-WebRequest -Uri $uri -OutFile $outFile -ErrorAction Stop
    } catch {
        Write-Host "[ERROR] Failed to download '$($file.RepoPath)'. Please check your internet connection and the repository URL." -ForegroundColor Red
        Read-Host "Press Enter to exit."
        exit 1
    }
}

Write-Host "[OK] All required files have been downloaded successfully." -ForegroundColor Green