param(
    [string]$InstallPath = $PSScriptRoot
)

<#
.SYNOPSIS
    A PowerShell script to interactively download QWEN models for ComfyUI.
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
if (Get-Command 'nvidia-smi' -ErrorAction SilentlyContinue) {
    try {
        $gpuInfoCsv = nvidia-smi --query-gpu=name,memory.total --format=csv,noheader
        if ($gpuInfoCsv) {
            $gpuInfoParts = $gpuInfoCsv.Split(','); $gpuName = $gpuInfoParts[0].Trim(); $gpuMemoryMiB = ($gpuInfoParts[1] -replace ' MiB').Trim(); $gpuMemoryGiB = [math]::Round([int]$gpuMemoryMiB / 1024)
            Write-Log "GPU: $gpuName" -Color Green; Write-Log "VRAM: $gpuMemoryGiB GB" -Color Green
            
            # Recommendations based on QWEN models
            if ($gpuMemoryGiB -ge 24) { Write-Log "Recommendation: bf16 or fp8" -Color Cyan }
            elseif ($gpuMemoryGiB -ge 16) { Write-Log "Recommendation: GGUF Q8_0" -Color Cyan }
            elseif ($gpuMemoryGiB -ge 12) { Write-Log "Recommendation: GGUF Q5_K_S" -Color Cyan }
            else { Write-Log "Recommendation: GGUF Q4_K_S" -Color Cyan }
        }
    } catch { Write-Log "Could not retrieve GPU information. Error: $($_.Exception.Message)" -Color Red }
} else { Write-Log "No NVIDIA GPU detected (nvidia-smi not found). Please choose based on your hardware." -Color Gray }
Write-Log "-------------------------------------------------------------------------------"

# --- Ask all questions ---
$baseChoice = Ask-Question "Do you want to download QWEN base models? " @("A) bf16", "B) fp8", "C) All", "D) No") @("A", "B", "C", "D")
$ggufChoice = Ask-Question "Do you want to download QWEN GGUF models?" @("A) Q8_0", "B) Q5_K_S", "C) Q4_K_S", "D) All", "E) No") @("A", "B", "C", "D", "E")
$editChoice = Ask-Question "Do you want to download QWEN EDIT models? " @("A) bf16", "B) fp8", "C) All", "D) No") @("A", "B", "C", "D")
$editggufChoice = Ask-Question "Do you want to download QWEN EDIT GGUF models?" @("A) Q8_0", "B) Q5_K_S", "C) Q4_K_S", "D) All", "E) No") @("A", "B", "C", "D", "E")
$lightChoice = Ask-Question "Do you want to download QWEN Lightning LoRA? " @("A) 8 Steps", "B) 4 Steps", "C) All", "D) No") @("A", "B", "C", "D")

# --- Download files based on answers ---
Write-Log "Starting QWEN model downloads..." -Color Cyan
$baseUrl = "https://huggingface.co/UmeAiRT/ComfyUI-Auto_installer/resolve/main/models"
$QWENDiffDir = Join-Path $modelsPath "diffusion_models\QWEN"
$QWENUnetDir = Join-Path $modelsPath "unet\QWEN"
$QWENLoRADir = Join-Path $modelsPath "loras\QWEN"
$clipDir = Join-Path $modelsPath "clip"
$vaeDir = Join-Path $modelsPath "vae"
New-Item -Path $QWENDiffDir, $QWENUnetDir, $QWENLoRADir, $clipDir, $vaeDir -ItemType Directory -Force | Out-Null

$doDownload = ($baseChoice -ne 'D' -or $ggufChoice -ne 'E' -or $editChoice -ne 'D' -or $editggufChoice -ne 'E')

if ($doDownload) {
    Write-Log "Downloading QWEN common support files (VAE, CLIPs)..."
    Download-File -Uri "$baseUrl/vae/qwen_image_vae.safetensors" -OutFile (Join-Path $vaeDir "qwen_image_vae.safetensors")
}

if ($baseChoice -ne 'D') {
    Write-Log "Downloading QWEN base model..."
    if ($baseChoice -in 'A', 'C') {
        Download-File -Uri "$baseUrl/diffusion_models/qwen_image_bf16.safetensors" -OutFile (Join-Path $QWENUnetDir "qwen_image_bf16.safetensors")
        Download-File -Uri "$baseUrl/clip/qwen_2.5_vl_7b.safetensors" -OutFile (Join-Path $clipDir "qwen_2.5_vl_7b.safetensors")
    }
    if ($baseChoice -in 'B', 'C') {
        Download-File -Uri "$baseUrl/diffusion_models/qwen_image_fp8_e4m3fn.safetensors" -OutFile (Join-Path $QWENUnetDir "qwen_image_fp8_e4m3fn.safetensors")
        Download-File -Uri "$baseUrl/clip/qwen_2.5_vl_7b_fp8_scaled.safetensors" -OutFile (Join-Path $clipDir "qwen_2.5_vl_7b_fp8_scaled.safetensors")
    }
}

if ($ggufChoice -ne 'E') {
    Write-Log "Downloading QWEN GGUF models..."
    if ($ggufChoice -in 'A', 'D') {
        Download-File -Uri "$baseUrl/unet/QWEN/Qwen_Image_Distill-Q8_0.gguf" -OutFile (Join-Path $QWENUnetDir "Qwen_Image_Distill-Q8_0.gguf")
        Download-File -Uri "$baseUrl/clip/Qwen2.5-VL-7B-Instruct-UD-Q4_K_S.gguf" -OutFile (Join-Path $clipDir "Qwen2.5-VL-7B-Instruct-UD-Q4_K_S.gguf")
    }
    if ($ggufChoice -in 'B', 'D') {
        Download-File -Uri "$baseUrl/unet/QWEN/Qwen_Image_Distill-Q5_K_S.gguf" -OutFile (Join-Path $QWENUnetDir "Qwen_Image_Distill-Q5_K_S.gguf")
        Download-File -Uri "$baseUrl/clip/Qwen2.5-VL-7B-Instruct-UD-Q4_K_S.gguf" -OutFile (Join-Path $clipDir "Qwen2.5-VL-7B-Instruct-UD-Q4_K_S.gguf")
    }
    if ($ggufChoice -in 'C', 'D') {
        Download-File -Uri "$baseUrl/unet/QWEN/Qwen_Image_Distill-Q4_K_S.gguf" -OutFile (Join-Path $QWENUnetDir "Qwen_Image_Distill-Q4_K_S.gguf")
        Download-File -Uri "$baseUrl/clip/Qwen2.5-VL-7B-Instruct-UD-Q4_K_S.gguf" -OutFile (Join-Path $clipDir "Qwen2.5-VL-7B-Instruct-UD-Q4_K_S.gguf")
    }
}

if ($editChoice -ne 'D') {
    Write-Log "Downloading QWEN base model..."
    if ($editChoice -in 'A', 'C') {
        Download-File -Uri "$baseUrl/diffusion_models/qwen_image_edit_bf16.safetensors" -OutFile (Join-Path $QWENUnetDir "qwen_image_edit_bf16.safetensors")
        Download-File -Uri "$baseUrl/clip/qwen_2.5_vl_7b.safetensors" -OutFile (Join-Path $clipDir "qwen_2.5_vl_7b.safetensors")
    }
    if ($editChoice -in 'B', 'C') {
        Download-File -Uri "$baseUrl/diffusion_models/qwen_image_edit_fp8_e4m3fn.safetensors" -OutFile (Join-Path $QWENUnetDir "qwen_image_edit_fp8_e4m3fn.safetensors")
        Download-File -Uri "$baseUrl/clip/qwen_2.5_vl_7b_fp8_scaled.safetensors" -OutFile (Join-Path $clipDir "qwen_2.5_vl_7b_fp8_scaled.safetensors")
    }
}

if ($editggufChoice -ne 'E') {
    Write-Log "Downloading QWEN GGUF models..."
    if ($editggufChoice -in 'A', 'D') {
        Download-File -Uri "$baseUrl/unet/QWEN/Qwen_Image_Edit-Q8_0.gguf" -OutFile (Join-Path $QWENUnetDir "Qwen_Image_Edit-Q8_0.gguf")
        Download-File -Uri "$baseUrl/clip/Qwen2.5-VL-7B-Instruct-UD-Q4_K_S.gguf" -OutFile (Join-Path $clipDir "Qwen2.5-VL-7B-Instruct-UD-Q4_K_S.gguf")
    }
    if ($editggufChoice -in 'B', 'D') {
        Download-File -Uri "$baseUrl/unet/QWEN/Qwen_Image_Edit-Q5_K_S.gguf" -OutFile (Join-Path $QWENUnetDir "Qwen_Image_Edit-Q5_K_S.gguf")
        Download-File -Uri "$baseUrl/clip/Qwen2.5-VL-7B-Instruct-UD-Q4_K_S.gguf" -OutFile (Join-Path $clipDir "Qwen2.5-VL-7B-Instruct-UD-Q4_K_S.gguf")
    }
    if ($editggufChoice -in 'C', 'D') {
        Download-File -Uri "$baseUrl/unet/QWEN/Qwen_Image_Edit-Q4_K_S.gguf" -OutFile (Join-Path $QWENUnetDir "Qwen_Image_Edit-Q4_K_S.gguf")
        Download-File -Uri "$baseUrl/clip/Qwen2.5-VL-7B-Instruct-UD-Q4_K_S.gguf" -OutFile (Join-Path $clipDir "Qwen2.5-VL-7B-Instruct-UD-Q4_K_S.gguf")
    }
}

if ($lightChoice -ne 'D') {
    Write-Log "Downloading QWEN Lightning LoRA..."
    if ($lightChoice -in 'A', 'C') {
        Download-File -Uri "$baseUrl/loras/QWEN/Qwen-Image-Lightning-8steps-V2.0.safetensors" -OutFile (Join-Path $QWENLoRADir "Qwen-Image-Lightning-8steps-V2.0.safetensors")
        Download-File -Uri "$baseUrl/loras/QWEN/Qwen-Image-Edit-Lightning-8steps-V1.0.safetensors" -OutFile (Join-Path $QWENLoRADir "Qwen-Image-Edit-Lightning-8steps-V1.0.safetensors")
    }
    if ($lightChoice -in 'B', 'C') {
        Download-File -Uri "$baseUrl/loras/QWEN/Qwen-Image-Lightning-4steps-V2.0.safetensors" -OutFile (Join-Path $QWENLoRADir "Qwen-Image-Lightning-4steps-V2.0.safetensors")
        Download-File -Uri "$baseUrl/loras/QWEN/Qwen-Image-Edit-Lightning-4steps-V1.0.safetensors" -OutFile (Join-Path $QWENLoRADir "Qwen-Image-Edit-Lightning-4steps-V1.0.safetensors")
    }
}

Write-Log "QWEN model downloads complete." -Color Green
Read-Host "Press Enter to return to the main installer."