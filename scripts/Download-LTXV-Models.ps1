param(
    [string]$InstallPath = $PSScriptRoot
)

<#
.SYNOPSIS
    A PowerShell script to interactively download LTX-Video models for ComfyUI.
.DESCRIPTION
    This version corrects a major syntax error in the helper functions.
#>

#===========================================================================
# SECTION 1: HELPER FUNCTIONS & SETUP
#===========================================================================
$InstallPath = $InstallPath.Trim('"')
Import-Module (Join-Path $PSScriptRoot "UmeAiRTUtils.psm1") -Force

#===========================================================================
# SECTION 2: SCRIPT EXECUTION
#===========================================================================

$InstallPath = $InstallPath.Trim('"')
$modelsPath = Join-Path $InstallPath "models"
if (-not (Test-Path $modelsPath)) {
    Write-Log "Could not find ComfyUI models path at '$modelsPath'. Exiting." -Color Red
    Read-Host "Press Enter to exit."
    exit
}

# --- GPU Detection ---
Write-Log "-------------------------------------------------------------------------------"
Write-Log "Checking for NVIDIA GPU to provide model recommendations..." -Color Yellow
$gpuInfo = Get-GpuVramInfo
if ($gpuInfo) {
    Write-Log "GPU: $($gpuInfo.GpuName)" -Color Green
    Write-Log "VRAM: $($gpuInfo.VramGiB) GB" -Color Green
    # Recommendations based on LTXV models
    if ($gpuInfo.VramGiB -ge 30) { Write-Log "Recommendation: Base 13B" -Color Cyan }
    elseif ($gpuInfo.VramGiB -ge 24) { Write-Log "Recommendation: GGUF Q8_0" -Color Cyan }
    elseif ($gpuInfo.VramGiB -ge 16) { Write-Log "Recommendation: GGUF Q5_K_M" -Color Cyan }
    elseif ($gpuInfo.VramGiB -ge 7) { Write-Log "Recommendation: Base 2B or GGUF Q3_K_S" -Color Cyan }
    else { Write-Log "Recommendation: GGUF Q3_K_S (performance may vary)" -Color Cyan }
}
else { Write-Log "No NVIDIA GPU detected. Please choose based on your hardware." -Color Gray }
Write-Log "-------------------------------------------------------------------------------"

# --- Ask all questions ---
$baseChoice = Read-UserChoice "Do you want to download LTXV base models?" @("A) 13B (30Gb)", "B) 2B (7Gb)", "C) All", "D) No") @("A", "B", "C", "D")
$ggufChoice = Read-UserChoice "Do you want to download LTXV GGUF models?" @("A) Q8_0 (24GB Vram)", "B) Q5_K_M (16GB Vram)", "C) Q3_K_S (less than 12GB Vram)", "D) All", "E) No") @("A", "B", "C", "D", "E")

# --- Download files based on answers ---
Write-Log "Starting LTX-Video model downloads..." -Color Cyan
$baseUrl = "https://huggingface.co/UmeAiRT/ComfyUI-Auto_installer/resolve/main/models"
$ltxvChkptDir = Join-Path $modelsPath "checkpoints\LTXV"
$ltxvUnetDir = Join-Path $modelsPath "unet\LTXV"
$vaeDir = Join-Path $modelsPath "vae"
New-Item -Path $ltxvChkptDir, $ltxvUnetDir, $vaeDir -ItemType Directory -Force | Out-Null

$doDownload = ($baseChoice -ne 'D' -or $ggufChoice -ne 'E')

if ($doDownload) {
    Write-Log "Downloading LTXV common support file (VAE)..."
    Save-File -Uri "$baseUrl/vae/ltxv-13b-0.9.7-vae-BF16.safetensors" -OutFile (Join-Path $vaeDir "ltxv-13b-0.9.7-vae-BF16.safetensors")
}

if ($baseChoice -ne 'D') {
    Write-Log "Downloading LTXV base model(s)..."
    if ($baseChoice -in 'A', 'C') {
        Save-File -Uri "$baseUrl/checkpoints/LTXV/ltxv-13b-0.9.7-dev.safetensors" -OutFile (Join-Path $ltxvChkptDir "ltxv-13b-0.9.7-dev.safetensors")
    }
    if ($baseChoice -in 'B', 'C') {
        Save-File -Uri "$baseUrl/checkpoints/LTXV/ltxv-2b-0.9.6-dev-04-25.safetensors" -OutFile (Join-Path $ltxvChkptDir "ltxv-2b-0.9.6-dev-04-25.safetensors")
    }
}

if ($ggufChoice -ne 'E') {
    Write-Log "Downloading LTXV GGUF models..."
    if ($ggufChoice -in 'A', 'D') {
        Save-File -Uri "$baseUrl/unet/LTXV/ltxv-13b-0.9.7-dev-Q8_0.gguf" -OutFile (Join-Path $ltxvUnetDir "ltxv-13b-0.9.7-dev-Q8_0.gguf")
    }
    if ($ggufChoice -in 'B', 'D') {
        Save-File -Uri "$baseUrl/unet/LTXV/ltxv-13b-0.9.7-dev-Q5_K_M.gguf" -OutFile (Join-Path $ltxvUnetDir "ltxv-13b-0.9.7-dev-Q5_K_M.gguf")
    }
    if ($ggufChoice -in 'C', 'D') {
        Save-File -Uri "$baseUrl/unet/LTXV/ltxv-13b-0.9.7-dev-Q3_K_S.gguf" -OutFile (Join-Path $ltxvUnetDir "ltxv-13b-0.9.7-dev-Q3_K_S.gguf")
    }
}

Write-Log "LTX-Video model downloads complete." -Color Green
Read-Host "Press Enter to return to the main installer."