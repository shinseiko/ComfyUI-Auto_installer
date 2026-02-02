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
#$baseChoice = Read-UserChoice "Do you want to download LTXV base models?" @("A) 13B (30Gb)", "B) 2B (7Gb)", "C) All", "D) No") @("A", "B", "C", "D")
$ggufChoice = Read-UserChoice "Do you want to download LTXV GGUF models?" @("A) Q8_0 (24GB Vram)", "B) Q5_K_M (16GB Vram)", "C) Q3_K_S (less than 12GB Vram)", "D) All", "E) No") @("A", "B", "C", "D", "E")

# --- Download files based on answers ---
Write-Log "Starting LTX-2 model downloads..." -Color Cyan
$baseUrl = "https://huggingface.co/UmeAiRT/ComfyUI-Auto_installer/resolve/main/models"
$ltxvChkptDir = Join-Path $modelsPath "checkpoints\LTX2"
$ltxvUnetDir = Join-Path $modelsPath "unet\LTX2"
$vaeDir = Join-Path $modelsPath "vae"
New-Item -Path $ltxvChkptDir, $ltxvUnetDir, $vaeDir -ItemType Directory -Force | Out-Null

$doDownload = ($baseChoice -ne 'D' -or $ggufChoice -ne 'E')

if ($doDownload) {
    Write-Log "Downloading LTX2 VAE..."
    Save-File -Uri "$baseUrl/vae/LTX2_video_vae_bf16.safetensors" -OutFile (Join-Path $vaeDir "LTX2_video_vae_bf16.safetensors")
    Save-File -Uri "$baseUrl/vae/LTX2_audio_vae_bf16.safetensors" -OutFile (Join-Path $vaeDir "LTX2_audio_vae_bf16.safetensors")
    Write-Log "Downloading LTX2 text encoder..."
    Save-File -Uri "$baseUrl/clip/ltx-2-19b-embeddings_connector_dev_bf16.safetensors" -OutFile (Join-Path $vaeDir "ltx-2-19b-embeddings_connector_dev_bf16.safetensors")
    Save-File -Uri "$baseUrl/clip/gemma-3-12b-it-IQ4_XS.gguf" -OutFile (Join-Path $vaeDir "gemma-3-12b-it-IQ4_XS.gguf")
    Write-Log "Downloading LTX2 spatial upscaler..."
    Save-File -Uri "$baseUrl/upscale_models/ltx-2-spatial-upscaler-x2-1.0.safetensors" -OutFile (Join-Path $vaeDir "ltx-2-spatial-upscaler-x2-1.0.safetensors")
    Write-Log "Downloading recommanded LoRA..."
    Save-File -Uri "$baseUrl/loras/LTX-2/ltx-2-19b-distilled-lora-384.safetensors" -OutFile (Join-Path $vaeDir "ltx-2-19b-distilled-lora-384.safetensors")
    Save-File -Uri "$baseUrl/loras/LTX-2/ltx-2-19b-ic-lora-detailer.safetensors" -OutFile (Join-Path $vaeDir "ltx-2-19b-ic-lora-detailer.safetensors")
}

if ($ggufChoice -ne 'E') {
    Write-Log "Downloading LTX2 GGUF models..."
    if ($ggufChoice -in 'A', 'D') {
        Save-File -Uri "$baseUrl/unet/LTX-2/ltx-2-19b-dev-Q8_0.gguf" -OutFile (Join-Path $ltxvUnetDir "ltx-2-19b-dev-Q8_0.gguf")
    }
    if ($ggufChoice -in 'B', 'D') {
        Save-File -Uri "$baseUrl/unet/LTX-2/ltx-2-19b-dev-Q5_K_S.gguf" -OutFile (Join-Path $ltxvUnetDir "ltx-2-19b-dev-Q5_K_S.gguf")
    }
    if ($ggufChoice -in 'C', 'D') {
        Save-File -Uri "$baseUrl/unet/LTX-2/ltx-2-19b-dev-Q3_K_S.gguf" -OutFile (Join-Path $ltxvUnetDir "ltx-2-19b-dev-Q3_K_S.gguf")
    }
}

Write-Log "LTX-2 model downloads complete." -Color Green
Read-Host "Press Enter to return to the main installer."