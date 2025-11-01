param(
    [string]$InstallPath,
    # [CORRECTIF] Accepte le paramètre -SkipSelf (par défaut, il est faux)
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
    $uri = $baseUrl + $file.RepoPath
    $outFile = Join-Path $InstallPath $file.LocalPath

    $outDir = Split-Path -Path $outFile -Parent
    if (-not (Test-Path $outDir)) {
        New-Item -ItemType Directory -Path $outDir -Force | Out-Null
    }

    # ==================== DÉBUT DE LA CORRECTION ====================
    # 1. Gestion de l'auto-écrasement (Ignorer si -SkipSelf est Vrai)
    if ($SkipSelf -and $file.LocalPath -eq "UmeAiRT-Update-ComfyUI.bat") {
        Write-Host "  - Skipping download of UmeAiRT-Update-ComfyUI.bat (self-update disabled)" -Color Gray
        continue # Ignore ce fichier et passe au suivant
    }

    Write-Host "  - Downloading $($file.RepoPath)..."

    # 2. Gestion de l'encodage (compatible PS 5.1) pour éviter la corruption future
    try {
        if ($outFile -like "*.bat") {
            # Les .bat doivent être en ANSI (Default)
            $content = Invoke-WebRequest -Uri $uri -ErrorAction Stop -UseBasicParsing
            $content.Content | Set-Content -Path $outFile -Encoding Default
        } else {
            # Les autres fichiers sont OK avec la méthode simple
            Invoke-WebRequest -Uri $uri -OutFile $outFile -ErrorAction Stop -UseBasicParsing
        }
    # ==================== FIN DE LA CORRECTION ====================
    } catch {
        Write-Host "[ERROR] Failed to download '$($file.RepoPath)'." -ForegroundColor Red
        Write-Host "URL: $uri" -ForegroundColor DarkRed
        Write-Host "Destination: $outFile" -ForegroundColor DarkRed
        Read-Host "Press Enter to exit."
        exit 1
    }
}

Write-Host "[OK] All required files have been downloaded successfully." -ForegroundColor Green