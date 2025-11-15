param(
    # Accepts the installation path from the main script.
    # Defaults to its own directory if run standalone.
    [string]$InstallPath = $PSScriptRoot
)

<#
.SYNOPSIS
    A fully refactored and corrected PowerShell script to interactively download FLUX models for ComfyUI.
.DESCRIPTION
    This version corrects logging paths when called from a parent script, fixes all download logic,
    and provides user guidance based on GPU VRAM.
#>

#===========================================================================
# SECTION 1: HELPER FUNCTIONS & SETUP
#===========================================================================
$InstallPath = $InstallPath.Trim('"')
Import-Module (Join-Path $PSScriptRoot "UmeAiRTUtils.psm1") -Force

#===========================================================================
# SECTION 2: SCRIPT EXECUTION
#===========================================================================

$modelsPath = Join-Path $InstallPath "models"
if (-not (Test-Path $modelsPath)) {
    Write-Log "Models directory does not exist, creating it..." -Color Yellow
    # Create the directory (and any necessary parent directories thanks to -Force).
    New-Item -Path $modelsPath -ItemType Directory -Force | Out-Null
}

# --- GPU Detection ---
Write-Log "-------------------------------------------------------------------------------"
Write-Log "Checking for NVIDIA GPU to provide model recommendations..." -Color Yellow
if (Get-Command 'nvidia-smi' -ErrorAction SilentlyContinue) {
    try {
        $gpuInfoCsv = nvidia-smi --query-gpu=name,memory.total --format=csv,noheader
        if ($gpuInfoCsv) {
            $gpuInfoParts = $gpuInfoCsv.Split(',')
            $gpuName = $gpuInfoParts[0].Trim()
            $gpuMemoryMiB = ($gpuInfoParts[1] -replace ' MiB').Trim()
            $gpuMemoryGiB = [math]::Round([int]$gpuMemoryMiB / 1024)
            
            Write-Log "GPU: $gpuName" -Color Green
            Write-Log "VRAM: $gpuMemoryGiB GB" -Color Green
            
            if ($gpuMemoryGiB -ge 30) {
                Write-Log "Recommendation: fp16" -Color Cyan
            } elseif ($gpuMemoryGiB -ge 18) {
                Write-Log "Recommendation: fp8 or GGUF Q8" -Color Cyan
            } elseif ($gpuMemoryGiB -ge 16) {
                Write-Log "Recommendation: GGUF Q6" -Color Cyan
            }elseif ($gpuMemoryGiB -ge 14) {
                Write-Log "Recommendation: GGUF Q5" -Color Cyan
            }elseif ($gpuMemoryGiB -ge 12) {
                Write-Log "Recommendation: GGUF Q4" -Color Cyan
            }elseif ($gpuMemoryGiB -ge 8) {
                Write-Log "Recommendation: GGUF Q3" -Color Cyan
            }else {
                Write-Log "Recommendation: GGUF Q2" -Color Cyan
            }
        }
    } catch {
        Write-Log "Could not retrieve GPU information. Error: $($_.Exception.Message)" -Color Red
    }
} else {
    Write-Log "No NVIDIA GPU detected (nvidia-smi not found). Please choose based on your hardware." -Color Gray
}
Write-Log "-------------------------------------------------------------------------------"

# --- Ask all questions first ---
$fluxChoice = Ask-Question -Prompt "Do you want to download FLUX base models?" -Choices @("A) fp16", "B) fp8", "C) All", "D) No") -ValidAnswers @("A", "B", "C", "D")
$ggufChoice = Ask-Question -Prompt "Do you want to download FLUX GGUF models?" -Choices @("A) Q8 (18GB VRAM)","B) Q6 (14GB VRAM)", "C) Q5 (12GB VRAM)", "D) Q4 (10GB VRAM)", "E) Q3 (8GB VRAM)", "F) Q2 (6GB VRAM)", "G) All", "H) No") -ValidAnswers @("A", "B", "C", "D", "E", "F", "G", "H")
$nunchakuChoice = Ask-Question -Prompt "Do you want to download FLUX NUNCHAKU models?" -Choices @("A) Base", "B) Fill", "C) KONTEXT", "D) Krea", "E) All", "F) No") -ValidAnswers @("A", "B", "C", "D", "E", "F")
$schnellChoice = Ask-Question -Prompt "Do you want to download the FLUX SCHNELL model?" -Choices @("A) Yes", "B) No") -ValidAnswers @("A", "B")
$controlnetChoice = Ask-Question -Prompt "Do you want to download FLUX ControlNet models?" -Choices @("A) fp16", "B) fp8", "C) Q8", "D) Q5", "E) Q4", "F) All", "G) No") -ValidAnswers @("A", "B", "C", "D", "E", "F", "G")
$fillChoice = Ask-Question -Prompt "Do you want to download FLUX Fill models?" -Choices @("A) fp16", "B) fp8", "C) Q8", "D) Q6", "E) Q5", "F) Q4", "G) Q3", "H) All", "I) No") -ValidAnswers @("A", "B", "C", "D", "E", "F", "G", "H", "I")
$pulidChoice = Ask-Question -Prompt "Do you want to download FLUX PuLID and REDUX models?" -Choices @("A) Yes", "B) No") -ValidAnswers @("A", "B")
$upscaleChoice = Ask-Question -Prompt "Do you want to download Upscaler models ?" -Choices @("A) Yes", "B) No") -ValidAnswers @("A", "B")
$loraChoice = Ask-Question -Prompt "Do you want to download UmeAiRT LoRAs?" -Choices @("A) Yes", "B) No") -ValidAnswers @("A", "B")

# --- Download files based on answers ---
Write-Log "Starting downloads based on your choices..." -Color Cyan

# Define all paths once.
$baseUrl = "https://huggingface.co/UmeAiRT/ComfyUI-Auto_installer/resolve/main/models"
$fluxDir = Join-Path $modelsPath "diffusion_models\FLUX"
$clipDir = Join-Path $modelsPath "clip"
$vaeDir  = Join-Path $modelsPath "vae"
$unetFluxDir = Join-Path $modelsPath "unet\FLUX"
$controlnetDir = Join-Path $modelsPath "xlabs\controlnets"
$pulidDir = Join-Path $modelsPath "pulid"
$styleDir = Join-Path $modelsPath "style_models"
$loraDir = Join-Path $modelsPath "loras\FLUX"
$upscaleDir = Join-Path $modelsPath "upscale_models"

# Create all necessary directories at once.
$requiredDirs = @($fluxDir, $clipDir, $vaeDir, $unetFluxDir, $controlnetDir, $pulidDir, $styleDir, $loraDir, $upscaleDir)
foreach ($dir in $requiredDirs) {
    if (-not (Test-Path $dir)) {
        New-Item -Path $dir -ItemType Directory -Force | Out-Null
    }
}

# Check if any downloads are needed before downloading common files.
$doDownload = ($fluxChoice -ne 'D' -or $ggufChoice -ne 'H' -or $nunchakuChoice -ne 'F' -or $schnellChoice -eq 'A' -or $controlnetChoice -ne 'G' -or $fillChoice -ne 'I')

if ($doDownload) {
    Write-Log "Downloading common support models (VAE, CLIP)..."
    Download-File -Uri "$baseUrl/vae/ae.safetensors" -OutFile (Join-Path $vaeDir "ae.safetensors")
    Download-File -Uri "$baseUrl/clip/clip_l.safetensors" -OutFile (Join-Path $clipDir "clip_l.safetensors")
}

# FLUX Base Models
if ($fluxChoice -in 'A', 'C') {
    Download-File -Uri "$baseUrl/diffusion_models/FLUX/flux1-dev-fp16.safetensors" -OutFile (Join-Path $fluxDir "flux1-dev-fp16.safetensors")
    Download-File -Uri "$baseUrl/clip/t5xxl_fp16.safetensors" -OutFile (Join-Path $clipDir "t5xxl_fp16.safetensors")
}
if ($fluxChoice -in 'B', 'C') {
    Download-File -Uri "$baseUrl/diffusion_models/FLUX/flux1-dev-fp8.safetensors" -OutFile (Join-Path $fluxDir "flux1-dev-fp8.safetensors")
    Download-File -Uri "$baseUrl/clip/t5xxl_fp8_e4m3fn.safetensors" -OutFile (Join-Path $clipDir "t5xxl_fp8_e4m3fn.safetensors")
}

# GGUF Models
if ($ggufChoice -in 'A', 'G') {
    Download-File -Uri "$baseUrl/clip/t5-v1_1-xxl-encoder-Q8_0.gguf" -OutFile (Join-Path $clipDir "t5-v1_1-xxl-encoder-Q8_0.gguf")
    Download-File -Uri "$baseUrl/unet/FLUX/flux1-dev-Q8_0.gguf" -OutFile (Join-Path $unetFluxDir "flux1-dev-Q8_0.gguf")
}
if ($ggufChoice -in 'B', 'G') {
    Download-File -Uri "$baseUrl/clip/t5-v1_1-xxl-encoder-Q6_K.gguf" -OutFile (Join-Path $clipDir "t5-v1_1-xxl-encoder-Q6_K.gguf")
    Download-File -Uri "$baseUrl/unet/FLUX/flux1-dev-Q6_K.gguf" -OutFile (Join-Path $unetFluxDir "flux1-dev-Q6_K.gguf")
}
if ($ggufChoice -in 'C', 'G') {
    Download-File -Uri "$baseUrl/clip/t5-v1_1-xxl-encoder-Q5_K_M.gguf" -OutFile (Join-Path $clipDir "t5-v1_1-xxl-encoder-Q5_K_M.gguf")
    Download-File -Uri "$baseUrl/unet/FLUX/flux1-dev-Q5_K_S.gguf" -OutFile (Join-Path $unetFluxDir "flux1-dev-Q5_K_S.gguf")
}
if ($ggufChoice -in 'D', 'G') {
    Download-File -Uri "$baseUrl/clip/t5-v1_1-xxl-encoder-Q4_K_S.gguf" -OutFile (Join-Path $clipDir "t5-v1_1-xxl-encoder-Q4_K_S.gguf")
    Download-File -Uri "$baseUrl/unet/FLUX/flux1-dev-Q4_K_S.gguf" -OutFile (Join-Path $unetFluxDir "flux1-dev-Q4_K_S.gguf")
}
if ($ggufChoice -in 'E', 'G') {
    Download-File -Uri "$baseUrl/clip/t5-v1_1-xxl-encoder-Q3_K_S.gguf" -OutFile (Join-Path $clipDir "t5-v1_1-xxl-encoder-Q3_K_S.gguf")
    Download-File -Uri "$baseUrl/unet/FLUX/flux1-dev-Q3_K_S.gguf" -OutFile (Join-Path $unetFluxDir "flux1-dev-Q3_K_S.gguf")
}
if ($ggufChoice -in 'F', 'G') {
    Download-File -Uri "$baseUrl/unet/FLUX/flux1-dev-Q2_K.gguf" -OutFile (Join-Path $unetFluxDir "flux1-dev-Q2_K.gguf")
}

# NUNCHAKU Model
if ($nunchakuChoice -in 'A','E') { Download-File -Uri "$baseUrl/diffusion_models/FLUX/svdq-int4_r32-flux.1-dev.safetensors" -OutFile (Join-Path $fluxDir "svdq-int4_r32-flux.1-dev.safetensors") }
if ($nunchakuChoice -in 'B','E') { Download-File -Uri "$baseUrl/diffusion_models/FLUX/svdq-int4_r32-flux.1-fill-dev.safetensors" -OutFile (Join-Path $fluxDir "svdq-int4_r32-flux.1-fill-dev.safetensors") }
if ($nunchakuChoice -in 'C','E') { Download-File -Uri "$baseUrl/diffusion_models/FLUX/svdq-int4_r32-flux.1-kontext-dev.safetensors" -OutFile (Join-Path $fluxDir "svdq-int4_r32-flux.1-kontext-dev.safetensors") }
if ($nunchakuChoice -in 'D','E') { Download-File -Uri "$baseUrl/diffusion_models/FLUX/svdq-int4_r32-flux.1-krea-dev.safetensors" -OutFile (Join-Path $fluxDir "svdq-int4_r32-flux.1-krea-dev.safetensors") }

if ($nunchakuChoice -ne 'F') { Download-File -Uri "$baseUrl/clip/umt5_xxl_fp8_e4m3fn_scaled.safetensors" -OutFile (Join-Path $clipDir "umt5_xxl_fp8_e4m3fn_scaled.safetensors") }

# Schnell Model
if ($schnellChoice -eq 'A') {
    Download-File -Uri "$baseUrl/diffusion_models/FLUX/flux1-schnell-fp8.safetensors" -OutFile (Join-Path $fluxDir "flux1-schnell-fp8.safetensors")
}

# ControlNet Models
if ($controlnetChoice -ne 'G') {
    if ($controlnetChoice -in 'A','B','F') { 
        Download-File -Uri "$baseUrl/xlabs/controlnets/flux-canny-controlnet-v3.safetensors" -OutFile (Join-Path $controlnetDir "flux-canny-controlnet-v3.safetensors")
        Download-File -Uri "$baseUrl/xlabs/controlnets/flux-depth-controlnet-v3.safetensors" -OutFile (Join-Path $controlnetDir "flux-depth-controlnet-v3.safetensors")
    }
    if ($controlnetChoice -in 'A','F') { Download-File -Uri "$baseUrl/diffusion_models/FLUX/flux1-canny-dev-fp16.safetensors" -OutFile (Join-Path $fluxDir "flux1-canny-dev-fp16.safetensors"); Download-File -Uri "$baseUrl/diffusion_models/FLUX/flux1-depth-dev-fp16.safetensors" -OutFile (Join-Path $fluxDir "flux1-depth-dev-fp16.safetensors") }
    if ($controlnetChoice -in 'B','F') { Download-File -Uri "$baseUrl/diffusion_models/FLUX/flux1-canny-dev-fp8.safetensors" -OutFile (Join-Path $fluxDir "flux1-canny-dev-fp8.safetensors"); Download-File -Uri "$baseUrl/diffusion_models/FLUX/flux1-depth-dev-fp8.safetensors" -OutFile (Join-Path $fluxDir "flux1-depth-dev-fp8.safetensors") }
    if ($controlnetChoice -in 'C','F') { Download-File -Uri "$baseUrl/unet/FLUX/flux1-canny-dev-fp16-Q8_0-GGUF.gguf" -OutFile (Join-Path $unetFluxDir "flux1-canny-dev-fp16-Q8_0-GGUF.gguf"); Download-File -Uri "$baseUrl/unet/FLUX/flux1-depth-dev-fp16-Q8_0-GGUF.gguf" -OutFile (Join-Path $unetFluxDir "flux1-depth-dev-fp16-Q8_0-GGUF.gguf") }
    if ($controlnetChoice -in 'D','F') { Download-File -Uri "$baseUrl/unet/FLUX/flux1-canny-dev-fp16-Q5_0-GGUF.gguf" -OutFile (Join-Path $unetFluxDir "flux1-canny-dev-fp16-Q5_0-GGUF.gguf"); Download-File -Uri "$baseUrl/unet/FLUX/flux1-depth-dev-fp16-Q5_0-GGUF.gguf" -OutFile (Join-Path $unetFluxDir "flux1-depth-dev-fp16-Q5_0-GGUF.gguf") }
    if ($controlnetChoice -in 'E','F') { Download-File -Uri "$baseUrl/unet/FLUX/flux1-canny-dev-fp16-Q4_0-GGUF.gguf" -OutFile (Join-Path $unetFluxDir "flux1-canny-dev-fp16-Q4_0-GGUF.gguf"); Download-File -Uri "$baseUrl/unet/FLUX/flux1-depth-dev-fp16-Q4_0-GGUF.gguf" -OutFile (Join-Path $unetFluxDir "flux1-depth-dev-fp16-Q4_0-GGUF.gguf") }
}

# Fill Models
if ($fillChoice -in 'A','H') { Download-File -Uri "$baseUrl/diffusion_models/FLUX/flux1-fill-dev-fp16.safetensors" -OutFile (Join-Path $fluxDir "flux1-fill-dev-fp16.safetensors") }
if ($fillChoice -in 'B','H') { Download-File -Uri "$baseUrl/diffusion_models/FLUX/flux1-fill-dev-fp8.safetensors" -OutFile (Join-Path $fluxDir "flux1-fill-dev-fp8.safetensors") }
if ($fillChoice -in 'C','H') { Download-File -Uri "$baseUrl/unet/FLUX/flux1-fill-dev-Q8_0.gguf" -OutFile (Join-Path $unetFluxDir "flux1-fill-dev-Q8_0.gguf") }
if ($fillChoice -in 'D','H') { Download-File -Uri "$baseUrl/unet/FLUX/flux1-fill-dev-Q6_K.gguf" -OutFile (Join-Path $unetFluxDir "flux1-fill-dev-Q6_K.gguf") }
if ($fillChoice -in 'E','H') { Download-File -Uri "$baseUrl/unet/FLUX/flux1-fill-dev-Q5_K_S.gguf" -OutFile (Join-Path $unetFluxDir "flux1-fill-dev-Q5_K_S.gguf") }
if ($fillChoice -in 'F','H') { Download-File -Uri "$baseUrl/unet/FLUX/flux1-fill-dev-Q4_K_S.gguf" -OutFile (Join-Path $unetFluxDir "flux1-fill-dev-Q4_K_S.gguf") }
if ($fillChoice -in 'G','H') { Download-File -Uri "$baseUrl/unet/FLUX/flux1-fill-dev-Q3_K_S.gguf" -OutFile (Join-Path $unetFluxDir "flux1-fill-dev-Q3_K_S.gguf") }

# PuLID Models
if ($pulidChoice -eq 'A') {
    Download-File -Uri "$baseUrl/pulid/pulid_flux_v0.9.0.safetensors" -OutFile (Join-Path $pulidDir "pulid_flux_v0.9.0.safetensors")
    Download-File -Uri "$baseUrl/style_models/flux1-redux-dev.safetensors" -OutFile (Join-Path $styleDir "flux1-redux-dev.safetensors")
}

# Upscaler Models
if ($upscaleChoice -eq 'A') {
    Download-File -Uri "$baseUrl/upscale_models/RealESRGAN_x4plus.pth" -OutFile (Join-Path $upscaleDir "RealESRGAN_x4plus.pth")
    Download-File -Uri "$baseUrl/upscale_models/RealESRGAN_x4plus_anime_6B.pth" -OutFile (Join-Path $upscaleDir "RealESRGAN_x4plus_anime_6B.pth")
    Download-File -Uri "$baseUrl/upscale_models/4x-AnimeSharp.pth" -OutFile (Join-Path $upscaleDir "4x-AnimeSharp.pth")
    Download-File -Uri "$baseUrl/upscale_models/4x-UltraSharp.pth" -OutFile (Join-Path $upscaleDir "4x-UltraSharp.pth")
    Download-File -Uri "$baseUrl/upscale_models/4x_NMKD-Siax_200k.pth" -OutFile (Join-Path $upscaleDir "4x_NMKD-Siax_200k.pth")
    Download-File -Uri "$baseUrl/upscale_models/RealESRGAN_x4.pth" -OutFile (Join-Path $upscaleDir "RealESRGAN_x4.pth")
}

# LoRA Models
if ($loraChoice -eq 'A') {
    Download-File -Uri "https://huggingface.co/UmeAiRT/FLUX.1-dev-LoRA-Ume_Sky/resolve/main/ume_sky_v2.safetensors" -OutFile (Join-Path $loraDir "ume_sky_v2.safetensors")
    Download-File -Uri "https://huggingface.co/UmeAiRT/FLUX.1-dev-LoRA-Modern_Pixel_art/resolve/main/ume_modern_pixelart.safetensors" -OutFile (Join-Path $loraDir "ume_modern_pixelart.safetensors")
    Download-File -Uri "https://huggingface.co/UmeAiRT/FLUX.1-dev-LoRA-Romanticism/resolve/main/ume_classic_Romanticism.safetensors" -OutFile (Join-Path $loraDir "ume_classic_Romanticism.safetensors")
    Download-File -Uri "https://huggingface.co/UmeAiRT/FLUX.1-dev-LoRA-Impressionism/resolve/main/ume_classic_impressionist.safetensors" -OutFile (Join-Path $loraDir "ume_classic_impressionist.safetensors")
}

Write-Log "FLUX model downloads complete." -Color Green
Read-Host "Press Enter to return to the main installer."