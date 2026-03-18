<#
.SYNOPSIS
    Interactive downloader for WAN 2.2 models.
.DESCRIPTION
    Downloads WAN 2.2 Text-to-Video and Image-to-Video models (fp16, fp8, GGUF),
    Lightning LoRA, Fun Control, Fun Inpaint, and Fun Camera Control models.
    Each quantization includes both High Noise and Low Noise variants.
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

    if ($gpuInfo.VramGiB -ge 40) { Write-Log "Recommendation: fp16" -Color Cyan }
    elseif ($gpuInfo.VramGiB -ge 23) { Write-Log "Recommendation: fp8 or GGUF Q8" -Color Cyan }
    elseif ($gpuInfo.VramGiB -ge 16) { Write-Log "Recommendation: Q5_K_S" -Color Cyan }
    else { Write-Log "Recommendation: Q3_K_S" -Color Cyan }
}
else {
    Write-Log "No NVIDIA GPU detected. Please choose based on your hardware." -Color Gray
}
Write-Log "NOTE: Each option downloads both High Noise and Low Noise variants." -Color Yellow
Write-Log "-------------------------------------------------------------------------------"

# --- User Prompts ---
$T2VChoice      = Read-UserChoice -Prompt "Do you want to download WAN 2.2 text-to-video models?"         -Choices @("A) fp16", "B) fp8", "C) Q8_0", "D) Q5_K_S", "E) Q3_K_S", "F) All", "G) No") -ValidAnswers @("A","B","C","D","E","F","G")
$I2VChoice      = Read-UserChoice -Prompt "Do you want to download WAN 2.2 image-to-video models?"        -Choices @("A) fp16", "B) fp8", "C) Q8_0", "D) Q5_K_S", "E) Q3_K_S", "F) All", "G) No") -ValidAnswers @("A","B","C","D","E","F","G")
$LoRAChoice     = Read-UserChoice -Prompt "Do you want to download Lightning LoRAs (T2V + I2V)?"          -Choices @("A) Yes", "B) No") -ValidAnswers @("A","B")
$funcontrolChoice = Read-UserChoice -Prompt "Do you want to download WAN 2.2 Fun Control models?"         -Choices @("A) bf16", "B) fp8", "C) Q8_0", "D) Q5_K_S", "E) Q3_K_S", "F) All", "G) No") -ValidAnswers @("A","B","C","D","E","F","G")
$funinpaintChoice = Read-UserChoice -Prompt "Do you want to download WAN 2.2 Fun Inpaint models?"         -Choices @("A) bf16", "B) fp8", "C) Q8_0", "D) Q5_K_S", "E) Q3_K_S", "F) All", "G) No") -ValidAnswers @("A","B","C","D","E","F","G")
$funcameraChoice  = Read-UserChoice -Prompt "Do you want to download WAN 2.2 Fun Camera Control models?"  -Choices @("A) bf16", "B) fp8", "C) Q8_0", "D) Q5_K_S", "E) Q3_K_S", "F) All", "G) No") -ValidAnswers @("A","B","C","D","E","F","G")

# --- Download Process ---
Write-Log "Starting WAN 2.2 model downloads..." -Color Cyan

$baseUrl    = "https://huggingface.co/UmeAiRT/ComfyUI-Auto_installer/resolve/main/models"
$wanDiffDir = "$modelsPath/diffusion_models/WAN"
$wanUnetDir = "$modelsPath/unet/WAN"
$clipDir    = "$modelsPath/clip"
$vaeDir     = "$modelsPath/vae"
$visionDir  = "$modelsPath/clip_vision"
$loraDir    = "$modelsPath/loras/WAN2.2"

New-Item -Path $wanDiffDir, $wanUnetDir, $clipDir, $vaeDir, $visionDir, $loraDir -ItemType Directory -Force | Out-Null

$doDownload = ($T2VChoice -ne 'G' -or $I2VChoice -ne 'G' -or $LoRAChoice -eq 'A' -or $funcontrolChoice -ne 'G' -or $funinpaintChoice -ne 'G' -or $funcameraChoice -ne 'G')

if ($doDownload) {
    Write-Log "Downloading common support files..."
    Save-File -Uri "$baseUrl/vae/wan_2.1_vae.safetensors" -OutFile "$vaeDir/wan_2.1_vae.safetensors"
    Save-File -Uri "$baseUrl/text_encoders/T5/umt5-xxl-encoder-fp8-e4m3fn-scaled.safetensors" -OutFile "$clipDir/umt5-xxl-encoder-fp8-e4m3fn-scaled.safetensors"
}

if ($I2VChoice -ne 'G') {
    Save-File -Uri "$baseUrl/clip_vision/clip_vision_h.safetensors" -OutFile "$visionDir/clip_vision_h.safetensors"
}

# --- T2V ---
if ($T2VChoice -ne 'G') {
    Write-Log "Downloading T2V Models..."
    if ($T2VChoice -in 'A', 'F') {
        Save-File -Uri "$baseUrl/diffusion_models/WAN/wan2.2-t2v-high-noise-14b-fp16.safetensors" -OutFile "$wanDiffDir/wan2.2-t2v-high-noise-14b-fp16.safetensors"
        Save-File -Uri "$baseUrl/diffusion_models/WAN/wan2.2-t2v-low-noise-14b-fp16.safetensors"  -OutFile "$wanDiffDir/wan2.2-t2v-low-noise-14b-fp16.safetensors"
    }
    if ($T2VChoice -in 'B', 'F') {
        Save-File -Uri "$baseUrl/diffusion_models/WAN/wan2.2-t2v-high-noise-14b-fp8_scaled.safetensors" -OutFile "$wanDiffDir/wan2.2-t2v-high-noise-14b-fp8_scaled.safetensors"
        Save-File -Uri "$baseUrl/diffusion_models/WAN/wan2.2-t2v-low-noise-14b-fp8_scaled.safetensors"  -OutFile "$wanDiffDir/wan2.2-t2v-low-noise-14b-fp8_scaled.safetensors"
    }
    if ($T2VChoice -in 'C', 'F') {
        Save-File -Uri "$baseUrl/diffusion_models/WAN/Wan2.2-T2V-HighNoise-14B-Q8_0.gguf" -OutFile "$wanUnetDir/Wan2.2-T2V-HighNoise-14B-Q8_0.gguf"
        Save-File -Uri "$baseUrl/diffusion_models/WAN/Wan2.2-T2V-LowNoise-14B-Q8_0.gguf"  -OutFile "$wanUnetDir/Wan2.2-T2V-LowNoise-14B-Q8_0.gguf"
    }
    if ($T2VChoice -in 'D', 'F') {
        Save-File -Uri "$baseUrl/diffusion_models/WAN/Wan2.2-T2V-HighNoise-14B-Q5_K_S.gguf" -OutFile "$wanUnetDir/Wan2.2-T2V-HighNoise-14B-Q5_K_S.gguf"
        Save-File -Uri "$baseUrl/diffusion_models/WAN/Wan2.2-T2V-LowNoise-14B-Q5_K_S.gguf"  -OutFile "$wanUnetDir/Wan2.2-T2V-LowNoise-14B-Q5_K_S.gguf"
    }
    if ($T2VChoice -in 'E', 'F') {
        Save-File -Uri "$baseUrl/diffusion_models/WAN/Wan2.2-T2V-HighNoise-14B-Q3_K_S.gguf" -OutFile "$wanUnetDir/Wan2.2-T2V-HighNoise-14B-Q3_K_S.gguf"
        Save-File -Uri "$baseUrl/diffusion_models/WAN/Wan2.2-T2V-LowNoise-14B-Q3_K_S.gguf"  -OutFile "$wanUnetDir/Wan2.2-T2V-LowNoise-14B-Q3_K_S.gguf"
    }
}

# --- I2V ---
if ($I2VChoice -ne 'G') {
    Write-Log "Downloading I2V Models..."
    if ($I2VChoice -in 'A', 'F') {
        Save-File -Uri "$baseUrl/diffusion_models/WAN/wan2.2-i2v-high-noise-14b-fp16.safetensors" -OutFile "$wanDiffDir/wan2.2-i2v-high-noise-14b-fp16.safetensors"
        Save-File -Uri "$baseUrl/diffusion_models/WAN/wan2.2-i2v-low-noise-14b-fp16.safetensors"  -OutFile "$wanDiffDir/wan2.2-i2v-low-noise-14b-fp16.safetensors"
    }
    if ($I2VChoice -in 'B', 'F') {
        Save-File -Uri "$baseUrl/diffusion_models/WAN/wan2.2-i2v-high-noise-14b-fp8_scaled.safetensors" -OutFile "$wanDiffDir/wan2.2-i2v-high-noise-14b-fp8_scaled.safetensors"
        Save-File -Uri "$baseUrl/diffusion_models/WAN/wan2.2-i2v-low-noise-14b-fp8_scaled.safetensors"  -OutFile "$wanDiffDir/wan2.2-i2v-low-noise-14b-fp8_scaled.safetensors"
    }
    if ($I2VChoice -in 'C', 'F') {
        Save-File -Uri "$baseUrl/diffusion_models/WAN/Wan2.2-I2V-HighNoise-14B-Q8_0.gguf" -OutFile "$wanUnetDir/Wan2.2-I2V-HighNoise-14B-Q8_0.gguf"
        Save-File -Uri "$baseUrl/diffusion_models/WAN/Wan2.2-I2V-LowNoise-14B-Q8_0.gguf"  -OutFile "$wanUnetDir/Wan2.2-I2V-LowNoise-14B-Q8_0.gguf"
    }
    if ($I2VChoice -in 'D', 'F') {
        Save-File -Uri "$baseUrl/diffusion_models/WAN/Wan2.2-I2V-HighNoise-14B-Q5_K_S.gguf" -OutFile "$wanUnetDir/Wan2.2-I2V-HighNoise-14B-Q5_K_S.gguf"
        Save-File -Uri "$baseUrl/diffusion_models/WAN/Wan2.2-I2V-LowNoise-14B-Q5_K_S.gguf"  -OutFile "$wanUnetDir/Wan2.2-I2V-LowNoise-14B-Q5_K_S.gguf"
    }
    if ($I2VChoice -in 'E', 'F') {
        Save-File -Uri "$baseUrl/diffusion_models/WAN/Wan2.2-I2V-HighNoise-14B-Q3_K_S.gguf" -OutFile "$wanUnetDir/Wan2.2-I2V-HighNoise-14B-Q3_K_S.gguf"
        Save-File -Uri "$baseUrl/diffusion_models/WAN/Wan2.2-I2V-LowNoise-14B-Q3_K_S.gguf"  -OutFile "$wanUnetDir/Wan2.2-I2V-LowNoise-14B-Q3_K_S.gguf"
    }
}

# --- Lightning LoRAs ---
if ($LoRAChoice -eq 'A') {
    Write-Log "Downloading Lightning LoRAs..."
    Save-File -Uri "$baseUrl/loras/WAN2.2/Wan2.2-Lightning_T2V-A14B-4steps-lora_HIGH_fp16.safetensors" -OutFile "$loraDir/Wan2.2-Lightning_T2V-A14B-4steps-lora_HIGH_fp16.safetensors"
    Save-File -Uri "$baseUrl/loras/WAN2.2/Wan2.2-Lightning_T2V-A14B-4steps-lora_LOW_fp16.safetensors"  -OutFile "$loraDir/Wan2.2-Lightning_T2V-A14B-4steps-lora_LOW_fp16.safetensors"
    Save-File -Uri "$baseUrl/loras/WAN2.2/Wan2.2-Lightning_I2V-A14B-4steps-lora_HIGH_fp16.safetensors" -OutFile "$loraDir/Wan2.2-Lightning_I2V-A14B-4steps-lora_HIGH_fp16.safetensors"
    Save-File -Uri "$baseUrl/loras/WAN2.2/Wan2.2-Lightning_I2V-A14B-4steps-lora_LOW_fp16.safetensors"  -OutFile "$loraDir/Wan2.2-Lightning_I2V-A14B-4steps-lora_LOW_fp16.safetensors"
}

# --- Fun Control ---
if ($funcontrolChoice -ne 'G') {
    Write-Log "Downloading Fun Control Models..."
    if ($funcontrolChoice -in 'A', 'F') {
        Save-File -Uri "$baseUrl/diffusion_models/WAN/wan2.2-fun-control-high-noise-14b-bf16.safetensors" -OutFile "$wanDiffDir/wan2.2-fun-control-high-noise-14b-bf16.safetensors"
        Save-File -Uri "$baseUrl/diffusion_models/WAN/wan2.2-fun-control-low-noise-14b-bf16.safetensors"  -OutFile "$wanDiffDir/wan2.2-fun-control-low-noise-14b-bf16.safetensors"
    }
    if ($funcontrolChoice -in 'B', 'F') {
        Save-File -Uri "$baseUrl/diffusion_models/WAN/wan2.2-fun-control-high-noise-14b-fp8_scaled.safetensors" -OutFile "$wanDiffDir/wan2.2-fun-control-high-noise-14b-fp8_scaled.safetensors"
        Save-File -Uri "$baseUrl/diffusion_models/WAN/wan2.2-fun-control-low-noise-14b-fp8_scaled.safetensors"  -OutFile "$wanDiffDir/wan2.2-fun-control-low-noise-14b-fp8_scaled.safetensors"
    }
    if ($funcontrolChoice -in 'C', 'F') {
        Save-File -Uri "$baseUrl/diffusion_models/WAN/Wan2.2-Fun-Control-HighNoise-14B-Q8_0.gguf" -OutFile "$wanUnetDir/Wan2.2-Fun-Control-HighNoise-14B-Q8_0.gguf"
        Save-File -Uri "$baseUrl/diffusion_models/WAN/Wan2.2-Fun-Control-LowNoise-14B-Q8_0.gguf"  -OutFile "$wanUnetDir/Wan2.2-Fun-Control-LowNoise-14B-Q8_0.gguf"
    }
    if ($funcontrolChoice -in 'D', 'F') {
        Save-File -Uri "$baseUrl/diffusion_models/WAN/Wan2.2-Fun-Control-HighNoise-14B-Q5_K_S.gguf" -OutFile "$wanUnetDir/Wan2.2-Fun-Control-HighNoise-14B-Q5_K_S.gguf"
        Save-File -Uri "$baseUrl/diffusion_models/WAN/Wan2.2-Fun-Control-LowNoise-14B-Q5_K_S.gguf"  -OutFile "$wanUnetDir/Wan2.2-Fun-Control-LowNoise-14B-Q5_K_S.gguf"
    }
    if ($funcontrolChoice -in 'E', 'F') {
        Save-File -Uri "$baseUrl/diffusion_models/WAN/Wan2.2-Fun-Control-HighNoise-14B-Q3_K_S.gguf" -OutFile "$wanUnetDir/Wan2.2-Fun-Control-HighNoise-14B-Q3_K_S.gguf"
        Save-File -Uri "$baseUrl/diffusion_models/WAN/Wan2.2-Fun-Control-LowNoise-14B-Q3_K_S.gguf"  -OutFile "$wanUnetDir/Wan2.2-Fun-Control-LowNoise-14B-Q3_K_S.gguf"
    }
}

# --- Fun Inpaint ---
if ($funinpaintChoice -ne 'G') {
    Write-Log "Downloading Fun Inpaint Models..."
    if ($funinpaintChoice -in 'A', 'F') {
        Save-File -Uri "$baseUrl/diffusion_models/WAN/wan2.2-fun-inpaint-high-noise-14b-bf16.safetensors" -OutFile "$wanDiffDir/wan2.2-fun-inpaint-high-noise-14b-bf16.safetensors"
        Save-File -Uri "$baseUrl/diffusion_models/WAN/wan2.2-fun-inpaint-low-noise-14b-bf16.safetensors"  -OutFile "$wanDiffDir/wan2.2-fun-inpaint-low-noise-14b-bf16.safetensors"
    }
    if ($funinpaintChoice -in 'B', 'F') {
        Save-File -Uri "$baseUrl/diffusion_models/WAN/wan2.2-fun-inpaint-high-noise-14b-fp8_scaled.safetensors" -OutFile "$wanDiffDir/wan2.2-fun-inpaint-high-noise-14b-fp8_scaled.safetensors"
        Save-File -Uri "$baseUrl/diffusion_models/WAN/wan2.2-fun-inpaint-low-noise-14b-fp8_scaled.safetensors"  -OutFile "$wanDiffDir/wan2.2-fun-inpaint-low-noise-14b-fp8_scaled.safetensors"
    }
    if ($funinpaintChoice -in 'C', 'F') {
        Save-File -Uri "$baseUrl/diffusion_models/WAN/Wan2.2-Fun-InP-HighNoise-14B-Q8_0.gguf" -OutFile "$wanUnetDir/Wan2.2-Fun-InP-HighNoise-14B-Q8_0.gguf"
        Save-File -Uri "$baseUrl/diffusion_models/WAN/Wan2.2-Fun-InP-LowNoise-14B-Q8_0.gguf"  -OutFile "$wanUnetDir/Wan2.2-Fun-InP-LowNoise-14B-Q8_0.gguf"
    }
    if ($funinpaintChoice -in 'D', 'F') {
        Save-File -Uri "$baseUrl/diffusion_models/WAN/Wan2.2-Fun-InP-HighNoise-14B-Q5_K_S.gguf" -OutFile "$wanUnetDir/Wan2.2-Fun-InP-HighNoise-14B-Q5_K_S.gguf"
        Save-File -Uri "$baseUrl/diffusion_models/WAN/Wan2.2-Fun-InP-LowNoise-14B-Q5_K_S.gguf"  -OutFile "$wanUnetDir/Wan2.2-Fun-InP-LowNoise-14B-Q5_K_S.gguf"
    }
    if ($funinpaintChoice -in 'E', 'F') {
        Save-File -Uri "$baseUrl/diffusion_models/WAN/Wan2.2-Fun-InP-HighNoise-14B-Q3_K_S.gguf" -OutFile "$wanUnetDir/Wan2.2-Fun-InP-HighNoise-14B-Q3_K_S.gguf"
        Save-File -Uri "$baseUrl/diffusion_models/WAN/Wan2.2-Fun-InP-LowNoise-14B-Q3_K_S.gguf"  -OutFile "$wanUnetDir/Wan2.2-Fun-InP-LowNoise-14B-Q3_K_S.gguf"
    }
}

# --- Fun Camera ---
if ($funcameraChoice -ne 'G') {
    Write-Log "Downloading Fun Camera Control Models..."
    if ($funcameraChoice -in 'A', 'F') {
        Save-File -Uri "$baseUrl/diffusion_models/WAN/wan2.2-fun-camera-high-noise-14b-bf16.safetensors" -OutFile "$wanDiffDir/wan2.2-fun-camera-high-noise-14b-bf16.safetensors"
        Save-File -Uri "$baseUrl/diffusion_models/WAN/wan2.2-fun-camera-low-noise-14b-bf16.safetensors"  -OutFile "$wanDiffDir/wan2.2-fun-camera-low-noise-14b-bf16.safetensors"
    }
    if ($funcameraChoice -in 'B', 'F') {
        Save-File -Uri "$baseUrl/diffusion_models/WAN/wan2.2-fun-camera-high-noise-14b-fp8_scaled.safetensors" -OutFile "$wanDiffDir/wan2.2-fun-camera-high-noise-14b-fp8_scaled.safetensors"
        Save-File -Uri "$baseUrl/diffusion_models/WAN/wan2.2-fun-camera-low-noise-14b-fp8_scaled.safetensors"  -OutFile "$wanDiffDir/wan2.2-fun-camera-low-noise-14b-fp8_scaled.safetensors"
    }
    if ($funcameraChoice -in 'C', 'F') {
        Save-File -Uri "$baseUrl/diffusion_models/WAN/Wan2.2-Fun-Camera-HighNoise-14B-Q8_0.gguf" -OutFile "$wanUnetDir/Wan2.2-Fun-Camera-HighNoise-14B-Q8_0.gguf"
        Save-File -Uri "$baseUrl/diffusion_models/WAN/Wan2.2-Fun-Camera-LowNoise-14B-Q8_0.gguf"  -OutFile "$wanUnetDir/Wan2.2-Fun-Camera-LowNoise-14B-Q8_0.gguf"
    }
    if ($funcameraChoice -in 'D', 'F') {
        Save-File -Uri "$baseUrl/diffusion_models/WAN/Wan2.2-Fun-Camera-HighNoise-14B-Q5_K_S.gguf" -OutFile "$wanUnetDir/Wan2.2-Fun-Camera-HighNoise-14B-Q5_K_S.gguf"
        Save-File -Uri "$baseUrl/diffusion_models/WAN/Wan2.2-Fun-Camera-LowNoise-14B-Q5_K_S.gguf"  -OutFile "$wanUnetDir/Wan2.2-Fun-Camera-LowNoise-14B-Q5_K_S.gguf"
    }
    if ($funcameraChoice -in 'E', 'F') {
        Save-File -Uri "$baseUrl/diffusion_models/WAN/Wan2.2-Fun-Camera-HighNoise-14B-Q3_K_S.gguf" -OutFile "$wanUnetDir/Wan2.2-Fun-Camera-HighNoise-14B-Q3_K_S.gguf"
        Save-File -Uri "$baseUrl/diffusion_models/WAN/Wan2.2-Fun-Camera-LowNoise-14B-Q3_K_S.gguf"  -OutFile "$wanUnetDir/Wan2.2-Fun-Camera-LowNoise-14B-Q3_K_S.gguf"
    }
}

Write-Log "WAN 2.2 model downloads complete." -Color Green
Read-Host "Press Enter to return to the main installer."
