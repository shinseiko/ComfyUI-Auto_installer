---
paths:
  - "**/*.ps1"
  - "**/*.psm1"
  - "**/*.psd1"
---
# PowerShell Coding Standards

> Project-specific rules for ComfyUI Auto-Installer PowerShell scripts

## Critical Security Patterns

### Download Validation
```powershell
# ALWAYS validate downloads before execution
function Verify-Download {
    param($FilePath, $ExpectedHash)

    $actualHash = (Get-FileHash $FilePath -Algorithm SHA256).Hash
    if ($actualHash -ne $ExpectedHash) {
        throw "Security: Hash mismatch on $FilePath"
    }
}
```

### TLS Enforcement
```powershell
# ALWAYS at script start
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
```

### Never Use Invoke-Expression with External Data
```powershell
# ❌ DANGEROUS
Invoke-Expression (Invoke-WebRequest $url).Content

# ✅ SAFE
$tempFile = Join-Path $env:TEMP "script.ps1"
Invoke-WebRequest $url -OutFile $tempFile
Verify-Download $tempFile $expectedHash
& $tempFile
```

## Path Handling (CRITICAL)

### ALWAYS Use Join-Path
```powershell
# ✅ CORRECT
$configPath = Join-Path $scriptPath "config.json"

# ❌ WRONG
$configPath = "$scriptPath\config.json"
```

### Quote Paths with Spaces
```powershell
# ✅ CORRECT
& "C:\Program Files\Git\bin\git.exe" clone $url

# ❌ WRONG
C:\Program Files\Git\bin\git.exe clone $url
```

## Error Handling

### Use Try-Catch
```powershell
try {
    Invoke-WebRequest $url -OutFile $destination
} catch {
    Write-Log "ERROR: $($_.Exception.Message)" -Level 0 -Color Red
    throw
}
```

### Use Invoke-AndLog (Project Standard)
```powershell
# Preferred method
Invoke-AndLog -File "pip" -Arguments "install -r requirements.txt"
```

## Logging Standards

### Use Write-Log from UmeAiRTUtils.psm1
```powershell
Write-Log "Installing..." -Level 0  # Step header (Yellow)
Write-Log "Cloning repo" -Level 1   # Main item (White)
Write-Log "Branch: main" -Level 2   # Sub-item (White)
Write-Log "Debug info" -Level 3     # Debug (DarkGray)
```

## Junction-Based Architecture (CRITICAL)

### Never Modify ComfyUI Core Folders
```powershell
# ✅ CORRECT - Use external folders
$modelsPath = Join-Path $installPath "models"
cmd /c mklink /J "$comfyModels" "$modelsPath"

# ❌ WRONG - Breaks git pull
Copy-Item $model (Join-Path $comfyPath "models\file.safetensors")
```

## Immutability

### Never Modify Original Files
```powershell
# ❌ BAD
$config = Get-Content config.json | ConvertFrom-Json
$config.setting = "new"
$config | ConvertTo-Json | Set-Content config.json

# ✅ GOOD - Backup first
Copy-Item config.json config.json.bak
```

## Common Pitfalls

❌ Don't use cd (changes global state)
❌ Don't hardcode paths
❌ Don't skip download validation
❌ Don't modify ComfyUI/ repository files
