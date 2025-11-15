# --- Fonctions utilitaires partagées pour UmeAiRT ---

function Write-Log {
    param([string]$Message, [int]$Level = 1, [string]$Color = "Default")
    
    # Assure que $logFile est défini, sinon utilise un fallback
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
        Write-Host "Erreur interne dans Write-Log: $($_.Exception.Message)" -ForegroundColor Red
    }
}

function Invoke-AndLog {
    param( [string]$File, [string]$Arguments, [switch]$IgnoreErrors )
    
    # Assure que $logFile est défini
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
            Write-Log "ERREUR: La commande a échoué avec le code $LASTEXITCODE." -Color Red
            Write-Log "Commande: $File $Arguments" -Color Red
            Write-Log "Sortie de l'erreur:" -Color Red
            $output | ForEach-Object { Write-Host $_ -ForegroundColor Red; Add-Content -Path $global:logFile -Value $_ -ErrorAction SilentlyContinue }
            throw "L'exécution de la commande a échoué. Vérifiez les logs."
        } else { Add-Content -Path $global:logFile -Value $output -ErrorAction SilentlyContinue }
    } catch {
        $errMsg = "ERREUR FATALE lors de la tentative d'exécution: $File $Arguments. Erreur: $($_.Exception.Message)"
        Write-Log $errMsg -Color Red
        Add-Content -Path $global:logFile -Value $errMsg -ErrorAction SilentlyContinue
        Read-Host "Une erreur fatale est survenue. Appuyez sur Entrée pour quitter."
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
    
    # Chemin attendu pour aria2c.exe (installé par Phase 1)
    $aria2ExePath = Join-Path $env:LOCALAPPDATA "aria2\aria2c.exe"
    
    try {
        # --- Solution Rapide (Aria2) ---
        if (-not (Test-Path $aria2ExePath)) {
            # Force une erreur pour sauter au bloc 'catch' (le fallback)
            throw "aria2c.exe not found at '$aria2ExePath'."
        }
        
        Write-Log "Using aria2c from '$aria2ExePath'..." -Level 3
        $OutDir = Split-Path -Path $OutFile -Parent
        $OutName = Split-Path -Path $OutFile -Leaf
        $aria2Args = "--console-log-level=warn --quiet=true -x 16 -s 16 -k 1M --dir=`"$OutDir`" --out=`"$OutName`" `"$Uri`""
        
        # Appelle aria2c. Si cela échoue, Invoke-AndLog lèvera une exception
        # qui sera attrapée par le 'catch' ci-dessous.
        Invoke-AndLog $aria2ExePath $aria2Args 
        
        Write-Log "Download successful (aria2c)." -Level 3

    } catch {
        # --- Solution Lente (Fallback) : Utiliser PowerShell ---
        # S'exécute si aria2c n'est pas trouvé OU si aria2c a échoué
        Write-Log "aria2c failed or not found ('$($_.Exception.Message)'), using slower Invoke-WebRequest..." -Level 3
        
        try {
            # Le correctif Tls12 est déjà ici, c'est parfait.
            [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12, [Net.SecurityProtocolType]::Tls13
            Invoke-WebRequest -Uri $Uri -OutFile $OutFile -UseBasicParsing -ErrorAction Stop
            Write-Log "Download successful (PowerShell)." -Level 3
        } catch {
            Write-Log "ERREUR: Download failed for '$Uri'. Error: $($_.Exception.Message)" -Color Red
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
        # nvidia-smi.exe is available (from conda env)
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
# --- FIN DU FICHIER ---
# Exporte les fonctions pour les rendre disponibles à l'importation
Export-ModuleMember -Function Write-Log, Invoke-AndLog, Download-File, Test-NvidiaGpu, Ask-Question