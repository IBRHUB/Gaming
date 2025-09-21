
if (!([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]"Administrator"))
{
    Start-Process PowerShell.exe -ArgumentList ("-NoProfile -ExecutionPolicy Bypass -File `"{0}`"" -f $PSCommandPath) -Verb RunAs
    Exit
}


$Host.UI.RawUI.WindowTitle = "Call of Duty Config"
$Host.UI.RawUI.BackgroundColor = "Black"
$Host.PrivateData.ProgressBackgroundColor = "Black"
$Host.PrivateData.ProgressForegroundColor = "White"
Clear-Host

function Get-FileFromWeb {
    param ([Parameter(Mandatory)][string]$URL, [Parameter(Mandatory)][string]$File)
    
    function Show-Progress {
        param ([Parameter(Mandatory)][Single]$TotalValue, [Parameter(Mandatory)][Single]$CurrentValue, [Parameter(Mandatory)][string]$ProgressText, [Parameter()][int]$BarSize = 40)
        $percent = $CurrentValue / $TotalValue
        $percentComplete = $percent * 100
        if ($psISE) { 
            Write-Progress "$ProgressText" -id 0 -percentComplete $percentComplete 
        } else { 
            Write-Host -NoNewLine "`r$ProgressText $('='.PadRight($BarSize * $percent, '=').PadRight($BarSize, '-')) $($percentComplete.ToString('##0.00').PadLeft(6)) % " 
        }
    }
    
    try {
        Write-Host "Starting download..." -ForegroundColor Green
        $request = [System.Net.HttpWebRequest]::Create($URL)
        $request.Timeout = 30000
        $response = $request.GetResponse()
        
        if ($response.StatusCode -eq 401 -or $response.StatusCode -eq 403 -or $response.StatusCode -eq 404) { 
            throw "Remote file either doesn't exist, is unauthorized, or is forbidden for '$URL'." 
        }
        
        if ($File -match '^\.\\') { $File = Join-Path (Get-Location -PSProvider 'FileSystem') ($File -Split '^\.')[1] }
        if ($File -and !(Split-Path $File)) { $File = Join-Path (Get-Location -PSProvider 'FileSystem') $File }
        if ($File) { 
            $fileDirectory = $([System.IO.Path]::GetDirectoryName($File))
            if (!(Test-Path($fileDirectory))) { 
                [System.IO.Directory]::CreateDirectory($fileDirectory) | Out-Null 
            }
        }
        
        [long]$fullSize = $response.ContentLength
        [byte[]]$buffer = new-object byte[] 1048576
        [long]$total = [long]$count = 0
        $reader = $response.GetResponseStream()
        $writer = new-object System.IO.FileStream $File, 'Create'
        
        do {
            $count = $reader.Read($buffer, 0, $buffer.Length)
            $writer.Write($buffer, 0, $count)
            $total += $count
            if ($fullSize -gt 0) { 
                Show-Progress -TotalValue $fullSize -CurrentValue $total -ProgressText "Downloading" 
            }
        } while ($count -gt 0)
        
        Write-Host ""
        Write-Host "Download completed successfully!" -ForegroundColor Green
    }
    catch {
        Write-Host "Download failed: $($_.Exception.Message)" -ForegroundColor Red
        throw $_
    }
    finally {
        if ($reader) { $reader.Close() }
        if ($writer) { $writer.Close() }
    }
}

function Show-ModernFilePicker {
    param([ValidateSet('Folder', 'File')]$Mode, [string]$fileType)
    
    if ($Mode -eq 'Folder') {
        $Title = 'Select Configuration Folder'
        $modeOption = $false
        $Filter = "Folders|`n"
    } else {
        $Title = 'Select File'
        $modeOption = $true
        if ($fileType) {
            $Filter = "$fileType Files (*.$fileType) | *.$fileType|All files (*.*)|*.*"
        } else {
            $Filter = 'All Files (*.*)|*.*'
        }
    }
    
    try {
        Add-Type -AssemblyName System.Windows.Forms
        $OpenFileDialog = New-Object System.Windows.Forms.OpenFileDialog
        $OpenFileDialog.AddExtension = $modeOption
        $OpenFileDialog.CheckFileExists = $modeOption
        $OpenFileDialog.DereferenceLinks = $true
        $OpenFileDialog.Filter = $Filter
        $OpenFileDialog.Multiselect = $false
        $OpenFileDialog.Title = $Title
        $OpenFileDialog.InitialDirectory = [Environment]::GetFolderPath('Desktop')

        if ($Mode -eq 'Folder') {
            $FolderBrowser = New-Object System.Windows.Forms.FolderBrowserDialog
            $FolderBrowser.Description = $Title
            $FolderBrowser.SelectedPath = "$env:USERPROFILE\Documents\Call of Duty\players"
            $result = $FolderBrowser.ShowDialog()
            if ($result -eq [System.Windows.Forms.DialogResult]::OK) {
                return $FolderBrowser.SelectedPath
            }
        } else {
            $result = $OpenFileDialog.ShowDialog()
            if ($result -eq [System.Windows.Forms.DialogResult]::OK) {
                return $OpenFileDialog.FileName
            }
        }
        return $null
    }
    catch {
        Write-Host "File picker error: $($_.Exception.Message)" -ForegroundColor Red
        return $null
    }
}

function Get-CPURecommendedRuleBased {
    param(
        [ValidateSet('Gaming','Production')] [string]$CpuProfile = 'Gaming',
        [switch]$VerboseLog
    )

    function W($msg,[ConsoleColor]$c='Gray'){ if($VerboseLog){ Write-Host $msg -ForegroundColor $c } }

    $BaseYearIntel = @{
        '9' = 2019; '10' = 2020; '11' = 2021; '12' = 2021; '13' = 2022; '14' = 2023; '15' = 2024
    }
    $BaseYearAMD = @{
        'Zen+'=2019; 'Zen 2'=2019; 'Zen 3'=2020; 'Zen 4'=2022; 'Zen 5'=2024
    }

    $FeaturePatterns = @{
        X3D = { param($n) $n -match 'X3D' }
        KS  = { param($n) $n -match 'KS\b' }
        KF  = { param($n) $n -match 'KF\b' }
        HX  = { param($n) $n -match 'HX\b' }
        U   = { param($n) $n -match '\bU\b' }
        H   = { param($n) $n -match '\bH(?!X)\b' }
        G   = { param($n) $n -match '\b[0-9]?G\b' }
    }

    $Cfg = @{
        Gaming = @{
            PCoreWeight=1.00; ECoreWeight=0.35; FreqFactor=1.00
            DesktopBonus=0.05; X3DBonus=0.10; HXBonus=0.05; APU_Penalty=-0.05; U_Penalty=-0.10
            DecayDesktopPerYear=0.03; DecayMobilePerYear=0.05; FloorDesktop=0.70; FloorMobile=0.60
        }
        Production = @{
            PCoreWeight=1.00; ECoreWeight=0.60; ThreadCoeff=0.08; FreqCoeff=0.50
            HXBonus=0.05; U_Penalty=-0.10
            DecayDesktopPerYear=0.03; DecayMobilePerYear=0.05; FloorDesktop=0.70; FloorMobile=0.60
        }
    }

    function Get-Decay($isMobile,[int]$age,$conf){
        if($isMobile){
            [math]::Max($conf.FloorMobile, 1.0 - $conf.DecayMobilePerYear*$age)
        } else {
            [math]::Max($conf.FloorDesktop, 1.0 - $conf.DecayDesktopPerYear*$age)
        }
    }

    function Get-RecommendedValue([double]$s){
        if ($s -ge 40) { 7 }
        elseif ($s -ge 30) { 6 }
        elseif ($s -ge 22) { 5 }
        elseif ($s -ge 16) { 4 }
        elseif ($s -ge 12) { 3 }
        elseif ($s -ge 8)  { 2 }
        else { 1 }
    }

    # ---------- Collect CPU ----------
    try { $cpu = Get-CimInstance Win32_Processor | Select-Object -First 1 } catch { $cpu = Get-WmiObject Win32_Processor | Select-Object -First 1 }
    $name    = $cpu.Name
    $cores   = [int]$cpu.NumberOfCores
    $threads = [int]$cpu.NumberOfLogicalProcessors
    $baseGHz = [double]$cpu.MaxClockSpeed / 1000.0

    $pC = [math]::Max(0, ($threads - $cores))
    $eC = [math]::Max(0, (2*$cores - $threads))
    if($pC -eq 0 -and $eC -eq 0){ $pC=$cores; $eC=0 }

    $isMobile = ($name -match '\b(U|H|HX|HS|HK)\b' -or $name -match 'Mobile')
    $segment  = if($isMobile){'Mobile'} else {'Desktop'}

    $turboEst = if($isMobile){ $baseGHz*1.05 } else { $baseGHz*1.10 }

    $brand = if($name -match 'Intel'){ 'Intel' } elseif($name -match 'AMD|Ryzen'){ 'AMD' } else { 'Unknown' }

    $baseYear = (Get-Date).Year - 2
    if($brand -eq 'Intel'){
        if($name -match '\b(9|10|11|12|13|14|15)9?0{0,1}0?[0-9]?\b' -or $name -match '\b(9th|10th|11th|12th|13th|14th|15th)\b'){
            if($name -match '\b(9|10|11|12|13|14|15)th\b'){ $g=$Matches[1] }
            elseif($name -match '\b1(5|4|3|2)900|\b11?900|\b10?900'){ $g=$Matches[1] }
        }
        if(-not $g){
            if($name -match 'Core\s+Ultra\s+(\d)'){ $g =  (15) }
            elseif($name -match '\b1(5|4|3|2)\d{3}K?F?S?'){ $g = $Matches[1] }
        }
        if($g){ $baseYear = $BaseYearIntel["$g"] }
    } elseif($brand -eq 'AMD'){
        if($name -match '9[0-9]{3}X3D|9[0-9]{3}X|9[0-9]{3}'){
            $baseYear = $BaseYearAMD['Zen 5']
        }
        elseif($name -match '7[0-9]{3}X3D|7[0-9]{3}'){
            # Zen 4/8000G
            if($name -match '78..X3D|79..X3D'){ $baseYear = $BaseYearAMD['Zen 4'] }
            else { $baseYear = $BaseYearAMD['Zen 4'] }
        }
        elseif($name -match '5[0-9]{3}'){ $baseYear = $BaseYearAMD['Zen 3'] }
        elseif($name -match '3[0-9]{3}'){ $baseYear = $BaseYearAMD['Zen 2'] }
        else { $baseYear = $BaseYearAMD['Zen+'] }
    }

    $thisYear = (Get-Date).Year
    $ageYears = [math]::Max(0, $thisYear - $baseYear)

    # Features from name
    $isX3D = & $FeaturePatterns.X3D $name
    $isKS  = & $FeaturePatterns.KS  $name
    $isKF  = & $FeaturePatterns.KF  $name
    $isHX  = & $FeaturePatterns.HX  $name
    $isU   = & $FeaturePatterns.U   $name
    $isG   = & $FeaturePatterns.G   $name

    if($CpuProfile -eq 'Gaming'){
        $c = $Cfg.Gaming
        $mix   = ($pC*$c.PCoreWeight) + ($eC*$c.ECoreWeight)
        $base  = $mix * ($turboEst * $c.FreqFactor)
        $decay = Get-Decay $isMobile $ageYears @{ DecayMobilePerYear=$c.DecayMobilePerYear; DecayDesktopPerYear=$c.DecayDesktopPerYear; FloorMobile=$c.FloorMobile; FloorDesktop=$c.FloorDesktop }
        $score = $base * $decay
        if($isX3D){ $score += $c.X3DBonus }
        if(-not $isMobile){ $score += $c.DesktopBonus }
        if($isHX){ $score += $c.HXBonus }
        if($isG){ $score += $c.APU_Penalty }
        if($isU){ $score += $c.U_Penalty }
        if($isKS){ $score += 0.02 }
        if($isKF){ $score += 0.00 }
    } else {
        $c = $Cfg.Production
        $coreMix = ($pC*$c.PCoreWeight) + ($eC*$c.ECoreWeight)
        $base  = $coreMix + ($threads*$c.ThreadCoeff) + ($turboEst*$c.FreqCoeff)
        $decay = Get-Decay $isMobile $ageYears @{ DecayMobilePerYear=$c.DecayMobilePerYear; DecayDesktopPerYear=$c.DecayDesktopPerYear; FloorMobile=$c.FloorMobile; FloorDesktop=$c.FloorDesktop }
        $score = $base * $decay
        if($isHX){ $score += $c.HXBonus }
        if($isU){ $score += $c.U_Penalty }
    }

    $recommended = Get-RecommendedValue $score

    [pscustomobject]@{
        Model        = $name
        Segment      = $segment
        Brand        = $brand
        BaseGHz      = [math]::Round($baseGHz,2)
        TurboEstGHz  = [math]::Round($turboEst,2)
        Cores        = $cores
        Threads      = $threads
        EstPCores    = $pC
        EstECores    = $eC
        YearApprox   = $baseYear
        AgeYears     = $ageYears
        Score        = [math]::Round($score,2)
        Recommended  = $recommended
        Profile      = $CpuProfile
        Source       = 'Rule-based (no big DB)'
        Flags        = @('X3D'[$isX3D],'KS'[$isKS],'KF'[$isKF],'HX'[$isHX],'U'[$isU],'G'[$isG]) | Where-Object { $_ -ne $null }
    }
}

function Get-CPUInfo {
    try {
        $currentCPU = (Get-WmiObject -Class Win32_Processor).Name
        
        $cpuDatabaseJsonUrl = "https://raw.githubusercontent.com/IBRHUB/Gaming/refs/heads/main/cpu_list_2019_2025.json"
        $tempJsonFile = "$env:TEMP\cpu_list_2019_2025.json"
        $cpuDatabaseJson = Join-Path $PSScriptRoot "cpu_database.json"
        
        $cpuData = $null
        $databaseType = ""
        $recommendedValue = 0
        
        Write-Host "INFO: Downloading CPU database from GitHub to temp directory..." -ForegroundColor Cyan
        try {
            Get-FileFromWeb -URL $cpuDatabaseJsonUrl -File $tempJsonFile
            
            if (Test-Path $tempJsonFile) {
                Write-Host "INFO: Downloaded CPU database to temp directory" -ForegroundColor Green
                
                $jsonContent = Get-Content $tempJsonFile -Raw -Encoding UTF8
                $cpuData = $jsonContent | ConvertFrom-Json
                $databaseType = "JSON"
                Write-Host "INFO: Using downloaded JSON CPU database from temp (with Recommended values)" -ForegroundColor Green
            } else {
                Write-Host "WARNING: Failed to download JSON database" -ForegroundColor Yellow
            }
        } catch {
            Write-Host "WARNING: Failed to download JSON database: $($_.Exception.Message)" -ForegroundColor Yellow
        }
        
        if (-not $cpuData -and (Test-Path $cpuDatabaseJson)) {
            try {
                $jsonContent = Get-Content $cpuDatabaseJson -Raw -Encoding UTF8
                $cpuData = $jsonContent | ConvertFrom-Json
                $databaseType = "JSON"
                Write-Host "INFO: Using local JSON CPU database" -ForegroundColor Green
            } catch {
                Write-Host "WARNING: Failed to parse local JSON database" -ForegroundColor Yellow
            }
        }
        
        if (-not $cpuData) {
            Write-Host "WARNING: No CPU database found, using rule-based fallback" -ForegroundColor Yellow
            
            $ruleBasedResult = Get-CPURecommendedRuleBased -CpuProfile 'Gaming'
            return @{
                Cores = $ruleBasedResult.Cores
                Recommended = $ruleBasedResult.Recommended
                Source = $ruleBasedResult.Source
                Model = $ruleBasedResult.Model
                Brand = $ruleBasedResult.Brand
                Segment = $ruleBasedResult.Segment
                Score = $ruleBasedResult.Score
            }
        }
        
        $matchedCPU = $null
        $cpuCores = 0
        $cpuBrand = ""
        $cpuGeneration = ""
        $cpuSegment = ""
        

        if ($databaseType -eq "JSON" -and $cpuData) {
            foreach ($cpu in $cpuData) {
                if ($cpu.Type -eq "Header") { continue }
                
                if ($currentCPU -like "*$($cpu.Model)*" -or $currentCPU -like "*$($cpu.Family)*") {
                    $matchedCPU = $cpu.Model
                    $cpuCores = [int]($cpu."Cores/Threads" -split 'C')[0]
                    $cpuBrand = $cpu.Brand.Trim()
                    $cpuGeneration = $cpu."Generation/Series".Trim()
                    $cpuSegment = $cpu.Segment.Trim()
                    $recommendedValue = [int]$cpu.Recommended
                    break
                }
            }
        }
        
        
        if ($matchedCPU) {
            if ($databaseType -eq "JSON" -and $recommendedValue) {
                $calculationMethod = "Direct from Database"
            } else {
                $recommendedValue = [Math]::Max(1, $cpuCores - 1)
                $calculationMethod = "P-Cores - 1"
            }
            
            return @{
                Cores = $cpuCores
                Recommended = $recommendedValue
                Model = $matchedCPU
                Brand = $cpuBrand
                Generation = $cpuGeneration
                Segment = $cpuSegment
                Source = "Database ($databaseType)"
                Calculation = $calculationMethod
            }
        } else {
            Write-Host "WARNING: CPU not found in database, using WMI fallback" -ForegroundColor Yellow
            $cpuCores = (Get-WmiObject -Class Win32_Processor).NumberOfCores
            $recommendedValue = [Math]::Max(1, $cpuCores - 1)
            return @{
                Cores = $cpuCores
                Recommended = $recommendedValue
                Source = "WMI"
                Model = $currentCPU
                Calculation = "Total Cores - 1"
            }
        }
    }
    catch {
        Write-Host "ERROR: Failed to detect CPU info, using defaults" -ForegroundColor Red
        return @{ Cores = 4; Recommended = 3; Source = "Default"; Model = "Unknown" }
    }
}

try {
    Write-Host "Call of Duty Configuration Tool     " -ForegroundColor Cyan
    Write-Host ""
    Write-Host "This tool will automatically configure your Call of Duty games" -ForegroundColor White
    Write-Host "with the optimal RendererWorkerCount for your CPU." -ForegroundColor White
    Write-Host ""
    Write-Host "IMPORTANT:" -ForegroundColor Red -NoNewline
    Write-Host " Run each Call of Duty game at least once to generate" -ForegroundColor Yellow
    Write-Host "           the initial config files before using this tool." -ForegroundColor Yellow
    Write-Host ""
    Write-Host "Supported games: MW2, MW3, Warzone, Black Ops 6" -ForegroundColor Green
    Write-Host ""
    Write-Host "Press any key to continue..." -ForegroundColor Cyan
    $null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
    taskkill /f /im cod.exe 2>$null
    Clear-Host

    # Get CPU Info
    $cpuInfo = Get-CPUInfo
    
    # Display CPU Information
    Clear-Host
    Write-Host "CPU: $($cpuInfo.Model) | P-Cores: $($cpuInfo.Cores) | Recommended: $($cpuInfo.Recommended)" -ForegroundColor Green
    Write-Host ""
    Write-Host "Press any key to continue..." -ForegroundColor Cyan
    $null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
    Clear-Host

    # Get user input
    do {
        Write-Host "RendererWorkerCount Options:" -ForegroundColor Yellow
        Write-Host "1. Use recommended ($($cpuInfo.Recommended))"
        Write-Host "2. Enter custom value"
        Write-Host "3. exit"
        $choice = Read-Host "Choice (1-3)"
        
        switch ($choice) {
            "1" { 
                $rendererWorkerCount = $cpuInfo.Recommended
                Write-Host "Using recommended: $rendererWorkerCount" -ForegroundColor Green
                break 
            }
            "2" { 
                do {
                    Write-Host "Enter RendererWorkerCount (1-32):" -ForegroundColor Cyan
                    $customInput = Read-Host "Value"
                    
                    if ([int]::TryParse($customInput, [ref]$null) -and [int]$customInput -ge 1 -and [int]$customInput -le 32) {
                        $rendererWorkerCount = [int]$customInput
                        Write-Host "Custom value: $rendererWorkerCount" -ForegroundColor Green
                        break
                    } else {
                        Write-Host "Invalid input! Enter 1-32" -ForegroundColor Red
                    }
                } while ($true)
                break 
            }
            "3" { 
                Write-Host "Exiting" -ForegroundColor Yellow
                exit 0 
            }
            default { 
                Write-Host "Invalid choice! Select 1, 2, or 3" -ForegroundColor Red
            }
        }
    } while ($choice -notin @('1','2','3'))
    
    Clear-Host
    Write-Host "Downloading config files..." -ForegroundColor Cyan

    $downloadUrl = "https://raw.githubusercontent.com/IBRHUB/Gaming/refs/heads/main/WZBO6MW2MW3.zip"
    $tempZip = "$env:TEMP\WZBO6MW2MW3.zip"
    $tempExtract = "$env:TEMP\WZBO6MW2MW3"

    Get-FileFromWeb -URL $downloadUrl -File $tempZip
    Write-Host "Extracting files..." -ForegroundColor Cyan
    Expand-Archive $tempZip -DestinationPath $tempExtract -Force
    Write-Host "Files ready!" -ForegroundColor Green
    Clear-Host
    
    $configFiles = @(
        "$tempExtract\players\options.3.cod22.cst",
        "$tempExtract\players\options.4.cod23.cst",
        "$tempExtract\players\s.1.0.cod24.txt0",
        "$tempExtract\players\s.1.0.cod24.txt1"
    )

    Write-Host "Updating config files..." -ForegroundColor Cyan
    
    $updatedCount = 0
    foreach ($file in $configFiles) {
        if (Test-Path $file) {
            (Get-Content $file) -replace '\$', $rendererWorkerCount | Set-Content $file
            $content = Get-Content -Path $file -Raw
            $encoding = New-Object System.Text.UTF8Encoding $false
            [System.IO.File]::WriteAllText($file, $content, $encoding)
            $updatedCount++
        }
    }
    
    Write-Host "Updated $updatedCount files with value: $rendererWorkerCount" -ForegroundColor Green
    Clear-Host

    # Install config files
    Write-Host "Installing to Call of Duty directories..." -ForegroundColor Cyan
    
    $installPaths = @(
        "$env:USERPROFILE\Documents\Call of Duty\players",
        "$env:USERPROFILE\OneDrive\Documents\Call of Duty\players"
    )

    $installedCount = 0
    foreach ($installPath in $installPaths) {
        if (Test-Path (Split-Path $installPath -Parent)) {
            New-Item -Path $installPath -ItemType Directory -Force -ErrorAction SilentlyContinue | Out-Null
            Copy-Item -Path "$tempExtract\players\*" -Destination $installPath -Recurse -Force -ErrorAction SilentlyContinue
            $installedCount++
        }
    }
    
    Write-Host "Installed to $installedCount directories" -ForegroundColor Green
    Clear-Host

    Write-Host "Select your User ID folder (optional):" -ForegroundColor Yellow
    $userFolder = Show-ModernFilePicker -Mode Folder
    
    if ($userFolder) {
        Copy-Item -Path "$tempExtract\YourID\*" -Destination $userFolder -Recurse -Force -ErrorAction SilentlyContinue
        Write-Host "User config installed" -ForegroundColor Green
    }

    Write-Host "Cleaning up..." -ForegroundColor Cyan
    Remove-Item $tempExtract -Recurse -Force -ErrorAction SilentlyContinue
    Remove-Item $tempZip -Force -ErrorAction SilentlyContinue

    Clear-Host
    Write-Host "Configuration Complete!" -ForegroundColor Green
    Write-Host "RendererWorkerCount: $rendererWorkerCount" -ForegroundColor White
    Write-Host ""
    Write-Host "Tips:" -ForegroundColor Yellow
    Write-Host "- Turn off HAGS in MW2 for better FPS"
    Write-Host "- Say 'No' to 'Set Optimal Settings & Run In Safe Mode'"
    Write-Host "- Restart shaders in Graphics settings"
}
catch {
    Write-Host "Error: $($_.Exception.Message)" -ForegroundColor Red
    Write-Host "Make sure you're running as Administrator" -ForegroundColor Yellow
}
finally {
    Write-Host ""
    Write-Host "Press any key to exit..." -ForegroundColor White
    $null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
}
