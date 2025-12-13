# --- Shared Utility Functions for UmeAiRT ---

function Write-Log {
    param([string]$Message, [int]$Level = 1, [string]$Color = "Default")
    
    # Ensure $logFile is defined, otherwise use fallback
    if (-not $global:logFile) {
        $global:logFile = Join-Path $PSScriptRoot "default_module_log.txt"
    }

    $prefix = ""
    $defaultColor = "White"
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    try {
        switch ($Level) {
            -2 { $prefix = "" }
            0 {
                $global:currentStep++
                $stepStr = "[Step $($global:currentStep)/$($global:totalSteps)]"
                $wrappedMessage = "| $stepStr $Message |"
                $separator = "=" * ($wrappedMessage.Length)
                $consoleMessage = "`n$separator`n$wrappedMessage`n$separator"
                $logMessage = "[$timestamp] $stepStr $Message"
                $defaultColor = "Yellow"
            }
            1 { $prefix = "  - " }
            2 { $prefix = "    -> " }
            3 { $prefix = "      [INFO] " }
        }
        if ($Color -eq "Default") { $Color = $defaultColor }
        if ($Level -ne 0) {
            $logMessage = "[$timestamp] $($prefix.Trim()) $Message"
            $consoleMessage = "$prefix$Message"
        }
        Write-Host $consoleMessage -ForegroundColor $Color
        Add-Content -Path $global:logFile -Value $logMessage -ErrorAction SilentlyContinue
    } catch {
        Write-Host "Internal error in Write-Log: $($_.Exception.Message)" -ForegroundColor Red
    }
}

function Invoke-AndLog {
    param( [string]$File, [string]$Arguments, [switch]$IgnoreErrors )
    
    # Ensure $logFile is defined
    if (-not $global:logFile) {
        $global:logFile = Join-Path $PSScriptRoot "default_module_log.txt"
    }
    
    $tempLogFile = Join-Path $env:TEMP ([System.Guid]::NewGuid().ToString() + ".tmp")
    try {
        Write-Log "Executing: $File $Arguments" -Level 3 -Color DarkGray
        $CommandToRun = "& `"$File`" $Arguments *>&1 | Out-File -FilePath `"$tempLogFile`" -Encoding utf8"
        Invoke-Expression $CommandToRun
        $output = if (Test-Path $tempLogFile) { Get-Content $tempLogFile } else { @() }
        if ($LASTEXITCODE -ne 0 -and -not $IgnoreErrors) {
            Write-Log "ERROR: Command failed with code $LASTEXITCODE." -Color Red
            Write-Log "Command: $File $Arguments" -Color Red
            Write-Log "Error Output:" -Color Red
            $output | ForEach-Object { Write-Host $_ -ForegroundColor Red; Add-Content -Path $global:logFile -Value $_ -ErrorAction SilentlyContinue }
            throw "Command execution failed. Check logs."
        } else { Add-Content -Path $global:logFile -Value $output -ErrorAction SilentlyContinue }
    } catch {
        $errMsg = "FATAL ERROR executing: $File $Arguments. Error: $($_.Exception.Message)"
        Write-Log $errMsg -Color Red
        Add-Content -Path $global:logFile -Value $errMsg -ErrorAction SilentlyContinue
        Read-Host "A fatal error occurred. Press Enter to exit."
        exit 1
    } finally { if (Test-Path $tempLogFile) { Remove-Item $tempLogFile -ErrorAction SilentlyContinue } }
}

function Download-File {
    param([string]$Uri, [string]$OutFile)
    
    if (Test-Path $OutFile) {
        $FileName = Split-Path -Path $OutFile -Leaf
        Write-Log "File '$FileName' already exists. Skipping download." -Level 2 -Color Green
        return
    }
    Write-Log "Downloading `"$($Uri.Split('/')[-1])`"" -Level 2 -Color DarkGray
    
    # Expected path for aria2c.exe (installed by Phase 1)
    $aria2ExePath = Join-Path $env:LOCALAPPDATA "aria2\aria2c.exe"
    
    try {
        # --- Attempt 1: Aria2 ---
        if (-not (Test-Path $aria2ExePath)) {
            throw "aria2c.exe not found at '$aria2ExePath'."
        }
        
        Write-Log "Using aria2c from '$aria2ExePath'..." -Level 3
        $OutDir = Split-Path -Path $OutFile -Parent
        $OutName = Split-Path -Path $OutFile -Leaf
        # Recreate argument string
        $aria2Args = "--console-log-level=warn --disable-ipv6 --quiet=true -x 16 -s 16 -k 1M --dir=`"$OutDir`" --out=`"$OutName`" `"$Uri`""
        
        Write-Log "Executing: $aria2ExePath $aria2Args" -Level 3 -Color DarkGray

        # Use Invoke-Expression to force PowerShell to parse argument string correctly
        $CommandToRun = "& `"$aria2ExePath`" $aria2Args 2>&1"
        $output = Invoke-Expression $CommandToRun | Out-String
        Add-Content -Path $global:logFile -Value $output -ErrorAction SilentlyContinue

        if ($LASTEXITCODE -ne 0) {
            # Catch failure and throw exception for fallback
            throw "aria2c command failed with code $LASTEXITCODE. Output: $output"
        }
        
        Write-Log "Download successful (aria2c)." -Level 3

    } catch {
        # --- Attempt 2: Fallback PowerShell ---
        # Runs if aria2c is not found OR if Invoke-Expression above failed
        Write-Log "aria2c failed or not found ('$($_.Exception.Message)'), using slower Invoke-WebRequest..." -Level 3
        
        try {
            [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12, [Net.SecurityProtocolType]::Tls13
            Invoke-WebRequest -Uri $Uri -OutFile $OutFile -UseBasicParsing -ErrorAction Stop
            Write-Log "Download successful (PowerShell)." -Level 3
        } catch {
            Write-Log "ERROR: Download failed for '$Uri'. Both aria2c and PowerShell failed. Error: $($_.Exception.Message)" -Color Red
            throw "Download failed."
        }
    }
}

function Ask-Question {
    param([string]$Prompt, [string[]]$Choices, [string[]]$ValidAnswers)
    $choice = ''
    while ($choice -notin $ValidAnswers) {
        Write-Log "`n$Prompt" -Color Yellow
        foreach ($line in $Choices) {
            Write-Host "  $line" -ForegroundColor Green
        }
        $choice = (Read-Host "Enter your choice and press Enter").ToUpper()
        if ($choice -notin $ValidAnswers) {
            Write-Log "Invalid choice. Please try again." -Color Red
        }
    }
    return $choice
}

function Test-NvidiaGpu {
    # This function must be called AFTER the Conda env is activated
    # (because it relies on nvidia-smi from the cuda-toolkit)

    Write-Log "Checking for NVIDIA GPU..." -Level 1
    try {
        # nvidia-smi.exe is available (from conda env or system)
        # -L lists GPUs. 2>&1 merges error and output streams.
        $gpuCheck = & "nvidia-smi" -L 2>&1 | Out-String

        if ($LASTEXITCODE -eq 0 -and $gpuCheck -match 'GPU 0:') {
            Write-Log "NVIDIA GPU detected." -Level 2 -Color Green
            Write-Log "$($gpuCheck.Trim())" -Level 3
            return $true # Return boolean TRUE
        } else {
            Write-Log "WARNING: No NVIDIA GPU detected. Skipping GPU-only packages." -Level 1 -Color Yellow
            Write-Log "nvidia-smi output (for debugging): $gpuCheck" -Level 3
            return $false # Return boolean FALSE
        }
    } catch {
        Write-Log "WARNING: 'nvidia-smi' command failed. Assuming no GPU." -Level 1 -Color Yellow
        Write-Log "Error details: $($_.Exception.Message)" -Level 3
        return $false # Return boolean FALSE
    }
}
# --- END OF FILE ---
Export-ModuleMember -Function Write-Log, Invoke-AndLog, Download-File, Test-NvidiaGpu, Ask-Question
