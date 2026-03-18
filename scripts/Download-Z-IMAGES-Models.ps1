<#
.SYNOPSIS
    Interactive downloader for Z-IMAGE Turbo models.
.DESCRIPTION
    Downloads Z-IMAGE Turbo BF16 (Base) and GGUF quantized models (Optimized).
    Also downloads RealESRGAN upscalers from the original source.
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
    Write-Log "Could not find ComfyUI models path at '$modelsPath'. Exiting." -Color Red
    Read-Host "Press Enter to exit."
    exit
}

# --- GPU Detection & Recommendation ---
Write-Log "-------------------------------------------------------------------------------"
Write-Log "Checking for NVIDIA GPU to provide model recommendations..." -Color Yellow
$gpuInfo = Get-GpuVramInfo
if ($gpuInfo) {
    Write-Log "GPU: $($gpuInfo.GpuName)" -Color Green
    Write-Log "VRAM: $($gpuInfo.VramGiB) GB" -Color Green
    if ($gpuInfo.VramGiB -ge 24)     { Write-Log "Recommendation: BF16 (Best Quality) or GGUF Q8_0" -Color Cyan }
    elseif ($gpuInfo.VramGiB -ge 16) { Write-Log "Recommendation: BF16 (Might use shared RAM) or GGUF Q8_0 (Safe)" -Color Cyan }
    elseif ($gpuInfo.VramGiB -ge 12) { Write-Log "Recommendation: GGUF Q8_0 (High Quality)" -Color Cyan }
    elseif ($gpuInfo.VramGiB -ge 10) { Write-Log "Recommendation: GGUF Q6_K" -Color Cyan }
    elseif ($gpuInfo.VramGiB -ge 8)  { Write-Log "Recommendation: GGUF Q5_K_S (Balanced) or Q4_K_S (Safe)" -Color Cyan }
    elseif ($gpuInfo.VramGiB -ge 6)  { Write-Log "Recommendation: GGUF Q3_K_S" -Color Cyan }
    else                              { Write-Log "Recommendation: GGUF Q3_K_S (Expect system memory usage)" -Color Red }
}
else {
    Write-Log "No NVIDIA GPU detected. Please choose based on your hardware." -Color Gray
}
Write-Log "-------------------------------------------------------------------------------"

# --- User Prompts ---
$baseChoice     = Read-UserChoice -Prompt "Do you want to download Z-IMAGE Turbo BF16 (Base Model)?"    -Choices @("A) Yes (Best Quality)", "B) No") -ValidAnswers @("A", "B")
$ggufChoice     = Read-UserChoice -Prompt "Do you want to download Z-IMAGE Turbo GGUF models?"          -Choices @("A) Q8_0 (High Quality)", "B) Q6_K", "C) Q5_K_S (Balanced)", "D) Q4_K_S (Fast)", "E) Q3_K_S (Low VRAM)", "F) All", "G) No") -ValidAnswers @("A", "B", "C", "D", "E", "F", "G")
$upscalerChoice = Read-UserChoice -Prompt "Do you want to download RealESRGAN Upscalers?"               -Choices @("A) Yes", "B) No") -ValidAnswers @("A", "B")

# --- Download Process ---
Write-Log "Starting Z-IMAGE Turbo model downloads..." -Color Cyan

$baseUrl     = "https://huggingface.co/UmeAiRT/ComfyUI-Auto_installer/resolve/main/models"
$esrganUrl   = "https://huggingface.co/spaces/Marne/Real-ESRGAN/resolve/main"

$ZImgUnetDir = "$modelsPath/unet/Z-IMG"
$ZImgDiffDir = "$modelsPath/diffusion_models/Z-IMG"
$clipDir     = "$modelsPath/clip"
$vaeDir      = "$modelsPath/vae"
$upscaleDir  = "$modelsPath/upscale_models"

New-Item -Path $ZImgUnetDir, $ZImgDiffDir, $clipDir, $vaeDir, $upscaleDir -ItemType Directory -Force | Out-Null

$doDownload = ($baseChoice -eq 'A' -or $ggufChoice -ne 'G')

if ($doDownload) {
    Write-Log "Downloading common support files (VAE)..."
    Save-File -Uri "$baseUrl/vae/ae.safetensors" -OutFile "$vaeDir/ae.safetensors"
}

if ($baseChoice -eq 'A') {
    Write-Log "Downloading Z-IMAGE Turbo BF16 base model..."
    Save-File -Uri "$baseUrl/diffusion_models/Z-IMG/z-image-turbo-bf16.safetensors" -OutFile "$ZImgDiffDir/z-image-turbo-bf16.safetensors"
    Save-File -Uri "$baseUrl/text_encoders/QWEN/qwen3-4b.safetensors"               -OutFile "$clipDir/qwen3-4b.safetensors"
}

if ($ggufChoice -ne 'G') {
    Write-Log "Downloading Z-IMAGE Turbo GGUF models..."
    if ($ggufChoice -in 'A', 'F') {
        Save-File -Uri "$baseUrl/diffusion_models/Z-IMG/Z-Image-Turbo-Q8_0.gguf" -OutFile "$ZImgUnetDir/Z-Image-Turbo-Q8_0.gguf"
        Save-File -Uri "$baseUrl/text_encoders/QWEN/Qwen3-4B-UD-Q8_K_XL.gguf"   -OutFile "$clipDir/Qwen3-4B-UD-Q8_K_XL.gguf"
    }
    if ($ggufChoice -in 'B', 'F') {
        Save-File -Uri "$baseUrl/diffusion_models/Z-IMG/Z-Image-Turbo-Q6_K.gguf" -OutFile "$ZImgUnetDir/Z-Image-Turbo-Q6_K.gguf"
        Save-File -Uri "$baseUrl/text_encoders/QWEN/Qwen3-4B-UD-Q6_K_XL.gguf"   -OutFile "$clipDir/Qwen3-4B-UD-Q6_K_XL.gguf"
    }
    if ($ggufChoice -in 'C', 'F') {
        Save-File -Uri "$baseUrl/diffusion_models/Z-IMG/Z-Image-Turbo-Q5_K_S.gguf" -OutFile "$ZImgUnetDir/Z-Image-Turbo-Q5_K_S.gguf"
        Save-File -Uri "$baseUrl/text_encoders/QWEN/Qwen3-4B-UD-Q5_K_XL.gguf"     -OutFile "$clipDir/Qwen3-4B-UD-Q5_K_XL.gguf"
    }
    if ($ggufChoice -in 'D', 'F') {
        Save-File -Uri "$baseUrl/diffusion_models/Z-IMG/Z-Image-Turbo-Q4_K_S.gguf" -OutFile "$ZImgUnetDir/Z-Image-Turbo-Q4_K_S.gguf"
        Save-File -Uri "$baseUrl/text_encoders/QWEN/Qwen3-4B-UD-Q4_K_XL.gguf"     -OutFile "$clipDir/Qwen3-4B-UD-Q4_K_XL.gguf"
    }
    if ($ggufChoice -in 'E', 'F') {
        Save-File -Uri "$baseUrl/diffusion_models/Z-IMG/Z-Image-Turbo-Q3_K_S.gguf" -OutFile "$ZImgUnetDir/Z-Image-Turbo-Q3_K_S.gguf"
        Save-File -Uri "$baseUrl/text_encoders/QWEN/Qwen3-4B-UD-Q3_K_XL.gguf"     -OutFile "$clipDir/Qwen3-4B-UD-Q3_K_XL.gguf"
    }
}

if ($upscalerChoice -eq 'A') {
    Write-Log "Downloading RealESRGAN Upscalers..."
    Save-File -Uri "$esrganUrl/RealESRGAN_x4plus.pth"          -OutFile "$upscaleDir/RealESRGAN_x4plus.pth"
    Save-File -Uri "$esrganUrl/RealESRGAN_x4plus_anime_6B.pth" -OutFile "$upscaleDir/RealESRGAN_x4plus_anime_6B.pth"
}

Write-Log "Z-IMAGE Turbo model downloads complete." -Color Green
Read-Host "Press Enter to return to the main installer."
