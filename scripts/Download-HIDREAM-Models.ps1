<#
.SYNOPSIS
    Interactive downloader for HiDream models.
.DESCRIPTION
    Downloads HiDream base models and GGUF quantized models for ComfyUI.
    Provides recommendations based on detected GPU VRAM.
.PARAMETER InstallPath
    The root directory of the installation.
#>

param(
    [string]$InstallPath = $PSScriptRoot
)

# ============================================================================
# INITIALIZATION
# ============================================================================
$InstallPath = $InstallPath.Trim('"').TrimEnd('\', '/').Replace('\', '/')
Import-Module "$($PSScriptRoot.Replace('\','/'))/UmeAiRTUtils.psm1" -Force

# ============================================================================
# MAIN EXECUTION
# ============================================================================

$modelsPath = "$InstallPath/models"
if (-not (Test-Path $modelsPath)) {
    Write-Log "Models directory does not exist, creating it..." -Color Yellow
    New-Item -Path $modelsPath -ItemType Directory -Force | Out-Null
}

# --- GPU Detection & Recommendations ---
Write-Log "-------------------------------------------------------------------------------"
Write-Log "Checking for NVIDIA GPU to provide model recommendations..." -Color Yellow
$gpuInfo = Get-GpuVramInfo
if ($gpuInfo) {
    Write-Log "GPU: $($gpuInfo.GpuName)" -Color Green
    Write-Log "VRAM: $($gpuInfo.VramGiB) GB" -Color Green

    if ($gpuInfo.VramGiB -ge 16) { Write-Log "Recommendation: fp8 or GGUF Q8" -Color Cyan }
    elseif ($gpuInfo.VramGiB -ge 8) { Write-Log "Recommendation: GGUF Q5" -Color Cyan }
    else { Write-Log "Recommendation: GGUF Q4 or lower" -Color Cyan }
}
else {
    Write-Log "No NVIDIA GPU detected. Please choose based on your hardware." -Color Gray
}
Write-Log "-------------------------------------------------------------------------------"

# --- User Prompts ---
$baseChoice = Read-UserChoice -Prompt "Do you want to download HiDream base model (fp8)?" -Choices @("A) fp8", "B) No") -ValidAnswers @("A", "B")
$ggufChoice = Read-UserChoice -Prompt "Do you want to download HiDream GGUF models?"     -Choices @("A) Q8_0", "B) Q6_K", "C) Q5_K_S", "D) Q4_K_S", "E) Q3_K_S", "F) All", "G) No") -ValidAnswers @("A", "B", "C", "D", "E", "F", "G")

# --- Download Process ---
Write-Log "Starting HiDream model downloads..." -Color Cyan

$baseUrl       = "https://huggingface.co/UmeAiRT/ComfyUI-Auto_installer/resolve/main/models"
$hidreamDiffDir = "$modelsPath/diffusion_models/HiDream"
$hidreamUnetDir = "$modelsPath/unet/HiDream"
$clipDir        = "$modelsPath/clip"

New-Item -Path $hidreamDiffDir, $hidreamUnetDir, $clipDir -ItemType Directory -Force | Out-Null

$doDownload = ($baseChoice -eq 'A' -or $ggufChoice -ne 'G')

if ($doDownload) {
    Write-Log "Downloading HiDream text encoders..."
    Save-File -Uri "$baseUrl/clip/clip_l_hidream.safetensors" -OutFile "$clipDir/clip_l_hidream.safetensors"
    Save-File -Uri "$baseUrl/clip/clip_g_hidream.safetensors" -OutFile "$clipDir/clip_g_hidream.safetensors"
}

if ($baseChoice -eq 'A') {
    Write-Log "Downloading HiDream fp8 base model..."
    Save-File -Uri "$baseUrl/diffusion_models/HiDream/hidream-i1-dev-fp8.safetensors" -OutFile "$hidreamDiffDir/hidream-i1-dev-fp8.safetensors"
}

if ($ggufChoice -ne 'G') {
    Write-Log "Downloading HiDream GGUF models..."
    if ($ggufChoice -in 'A', 'F') { Save-File -Uri "$baseUrl/diffusion_models/HiDream/HiDream-I1-Dev-Q8_0.gguf"   -OutFile "$hidreamUnetDir/HiDream-I1-Dev-Q8_0.gguf" }
    if ($ggufChoice -in 'B', 'F') { Save-File -Uri "$baseUrl/diffusion_models/HiDream/HiDream-I1-Dev-Q6_K.gguf"   -OutFile "$hidreamUnetDir/HiDream-I1-Dev-Q6_K.gguf" }
    if ($ggufChoice -in 'C', 'F') { Save-File -Uri "$baseUrl/diffusion_models/HiDream/HiDream-I1-Dev-Q5_K_S.gguf" -OutFile "$hidreamUnetDir/HiDream-I1-Dev-Q5_K_S.gguf" }
    if ($ggufChoice -in 'D', 'F') { Save-File -Uri "$baseUrl/diffusion_models/HiDream/HiDream-I1-Dev-Q4_K_S.gguf" -OutFile "$hidreamUnetDir/HiDream-I1-Dev-Q4_K_S.gguf" }
    if ($ggufChoice -in 'E', 'F') { Save-File -Uri "$baseUrl/diffusion_models/HiDream/HiDream-I1-Dev-Q3_K_S.gguf" -OutFile "$hidreamUnetDir/HiDream-I1-Dev-Q3_K_S.gguf" }
}

Write-Log "HiDream model downloads complete." -Color Green
Read-Host "Press Enter to return to the main installer."
