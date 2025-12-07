param(
    [string]$InstallPath = $PSScriptRoot
)

<#
.SYNOPSIS
    A PowerShell script to interactively download Z-IMAGE Turbo models for ComfyUI.
.DESCRIPTION
    Interactively selects and downloads Z-IMAGE Turbo BF16 and GGUF quantized models.
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

# --- GPU Detection & Recommendation ---
Write-Log "-------------------------------------------------------------------------------"
Write-Log "Checking for NVIDIA GPU to provide model recommendations..." -Color Yellow
if (Get-Command 'nvidia-smi' -ErrorAction SilentlyContinue) {
    try {
        $gpuInfoCsv = nvidia-smi --query-gpu=name,memory.total --format=csv,noheader
        if ($gpuInfoCsv) {
            $gpuInfoParts = $gpuInfoCsv.Split(','); $gpuName = $gpuInfoParts[0].Trim(); $gpuMemoryMiB = ($gpuInfoParts[1] -replace ' MiB').Trim(); $gpuMemoryGiB = [math]::Round([int]$gpuMemoryMiB / 1024)
            Write-Log "GPU: $gpuName" -Color Green; Write-Log "VRAM: $gpuMemoryGiB GB" -Color Green
            
            # Precise Recommendations based on file sizes + ~3-4GB overhead for System/CLIP/Context
            if ($gpuMemoryGiB -ge 24) { 
                Write-Log "Recommendation: BF16 (Best Quality) or GGUF Q8_0" -Color Cyan 
            }
            elseif ($gpuMemoryGiB -ge 16) { 
                Write-Log "Recommendation: BF16 (Might use shared RAM) or GGUF Q8_0 (Safe)" -Color Cyan 
            }
            elseif ($gpuMemoryGiB -ge 12) { 
                # Q8 is 7.22GB. Leaves ~4.8GB. Safe.
                Write-Log "Recommendation: GGUF Q8_0 (High Quality)" -Color Cyan 
            }
            elseif ($gpuMemoryGiB -ge 10) {
                # Q6 is 5.91GB. Leaves ~4GB. Safe.
                Write-Log "Recommendation: GGUF Q6_K" -Color Cyan
            }
            elseif ($gpuMemoryGiB -ge 8) { 
                # Q6 (5.9GB) is risky (leaves <2GB). 
                # Q5 (5.19GB) leaves ~2.8GB. Sweet spot.
                Write-Log "Recommendation: GGUF Q5_K_S (Balanced) or Q4_K_S (Safe)" -Color Cyan 
            }
            elseif ($gpuMemoryGiB -ge 6) { 
                # Q4 (4.66GB) is risky (leaves <1.4GB).
                # Q3 (3.79GB) leaves ~2.2GB. Safe.
                Write-Log "Recommendation: GGUF Q3_K_S" -Color Cyan 
            }
            else { 
                Write-Log "Recommendation: GGUF Q3_K_S (Expect system memory usage)" -Color Red 
            }
        }
    } catch { Write-Log "Could not retrieve GPU information. Error: $($_.Exception.Message)" -Color Red }
} else { Write-Log "No NVIDIA GPU detected. Please choose based on your hardware." -Color Gray }
Write-Log "-------------------------------------------------------------------------------"

# --- Interactive Questions ---
$baseChoice = Ask-Question "Do you want to download Z-IMAGE Turbo BF16 (Base Model)? " @("A) Yes (Best Quality)", "B) No") @("A", "B")
$ggufChoice = Ask-Question "Do you want to download Z-IMAGE Turbo GGUF models (Optimized)?" @("A) Q8_0 (High Quality)", "B) Q6_K", "C) Q5_K_S (Balanced)", "D) Q4_K_S (Fast)", "E) Q3_K_S (Low VRAM)", "F) All", "G) No") @("A", "B", "C", "D", "E", "F", "G")
$upscalerChoice = Ask-Question "Do you want to download RealESRGAN Upscalers? " @("A) Yes", "B) No") @("A", "B")

# --- Setup Paths ---
Write-Log "Starting Z-IMAGE Turbo model downloads..." -Color Cyan
$baseUrl = "https://huggingface.co/UmeAiRT/ComfyUI-Auto_installer/resolve/main/models"
$esrganUrl = "https://huggingface.co/spaces/Marne/Real-ESRGAN/resolve/main"

$ZImgUnetDir = Join-Path $modelsPath "unet\Z-IMG"
$ZImgDiffDir = Join-Path $modelsPath "diffusion_models\Z-IMG"
$clipDir = Join-Path $modelsPath "clip"
$vaeDir = Join-Path $modelsPath "vae"
$upscaleDir = Join-Path $modelsPath "upscale_models"

New-Item -Path $ZImgUnetDir, $ZImgDiffDir, $clipDir, $vaeDir, $upscaleDir -ItemType Directory -Force | Out-Null

# --- Determine if we need support files (VAE) ---
$doDownload = ($baseChoice -eq 'A' -or $ggufChoice -ne 'G')

if ($doDownload) {
    Write-Log "Downloading common support files (VAE)..."
    Download-File -Uri "$baseUrl/vae/ae.safetensors" -OutFile (Join-Path $vaeDir "ae.safetensors")
}

# --- Download BF16 Base Model ---
if ($baseChoice -eq 'A') {
    Write-Log "Downloading Z-IMAGE Turbo BF16 Base Model..."
    Download-File -Uri "$baseUrl/diffusion_models/Z-IMG/z_image_turbo_bf16.safetensors" -OutFile (Join-Path $ZImgDiffDir "z_image_turbo_bf16.safetensors")
    Download-File -Uri "$baseUrl/clip/qwen_3_4b.safetensors" -OutFile (Join-Path $clipDir "qwen_3_4b.safetensors")
}

# --- Download GGUF Models ---
if ($ggufChoice -ne 'G') {
    Write-Log "Downloading Z-IMAGE Turbo GGUF models..."
    
    # Option A: Q8 (High Quality) -> CLIP Q8
    if ($ggufChoice -in 'A', 'F') {
        Write-Log "Downloading Q8_0 Set (UNet + CLIP)..."
        Download-File -Uri "$baseUrl/unet/Z-IMG/z_image_turbo-Q8_0.gguf" -OutFile (Join-Path $ZImgUnetDir "z_image_turbo-Q8_0.gguf")
        Download-File -Uri "$baseUrl/clip/Qwen3-4B-UD-Q8_0.gguf" -OutFile (Join-Path $clipDir "Qwen3-4B-UD-Q8_0.gguf")
    }

    # Option B: Q6 (Good Quality) -> CLIP Q6
    if ($ggufChoice -in 'B', 'F') {
        Write-Log "Downloading Q6_K Set (UNet + CLIP)..."
        Download-File -Uri "$baseUrl/unet/Z-IMG/z_image_turbo-Q6_K.gguf" -OutFile (Join-Path $ZImgUnetDir "z_image_turbo-Q6_K.gguf")
        Download-File -Uri "$baseUrl/clip/Qwen3-4B-UD-Q6_K_XL.gguf" -OutFile (Join-Path $clipDir "Qwen3-4B-UD-Q6_K_XL.gguf")
    }

    # Option C: Q5 (Balanced) -> CLIP Q5
    if ($ggufChoice -in 'C', 'F') {
        Write-Log "Downloading Q5_K Set (UNet + CLIP)..."
        Download-File -Uri "$baseUrl/unet/Z-IMG/z_image_turbo-Q5_K_S.gguf" -OutFile (Join-Path $ZImgUnetDir "z_image_turbo-Q5_K_S.gguf")
        Download-File -Uri "$baseUrl/clip/Qwen3-4B-UD-Q5_K_M.gguf" -OutFile (Join-Path $clipDir "Qwen3-4B-UD-Q5_K_M.gguf")
    }

    # Option D: Q4 (Fast) -> CLIP Q4
    if ($ggufChoice -in 'D', 'F') {
        Write-Log "Downloading Q4_K Set (UNet + CLIP)..."
        Download-File -Uri "$baseUrl/unet/Z-IMG/z_image_turbo-Q4_K_S.gguf" -OutFile (Join-Path $ZImgUnetDir "z_image_turbo-Q4_K_S.gguf")
        Download-File -Uri "$baseUrl/clip/Qwen3-4B-UD-Q4_K_M.gguf" -OutFile (Join-Path $clipDir "Qwen3-4B-UD-Q4_K_M.gguf")
    }

    # Option E: Q3 (Low VRAM) -> CLIP Q3
    if ($ggufChoice -in 'E', 'F') {
        Write-Log "Downloading Q3_K Set (UNet + CLIP)..."
        Download-File -Uri "$baseUrl/unet/Z-IMG/z_image_turbo-Q3_K_S.gguf" -OutFile (Join-Path $ZImgUnetDir "z_image_turbo-Q3_K_S.gguf")
        Download-File -Uri "$baseUrl/clip/Qwen3-4B-UD-Q3_K_XL.gguf" -OutFile (Join-Path $clipDir "Qwen3-4B-UD-Q3_K_XL.gguf")
    }
}

# --- Download Upscalers ---
if ($upscalerChoice -eq 'A') {
    Write-Log "Downloading RealESRGAN Upscalers..."
    Download-File -Uri "$esrganUrl/RealESRGAN_x4plus.pth" -OutFile (Join-Path $upscaleDir "RealESRGAN_x4plus.pth")
    Download-File -Uri "$esrganUrl/RealESRGAN_x4plus_anime_6B.pth" -OutFile (Join-Path $upscaleDir "RealESRGAN_x4plus_anime_6B.pth")
}

Write-Log "Z-IMAGE Turbo model downloads complete." -Color Green
Read-Host "Press Enter to return to the main installer."