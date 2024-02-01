<#
.SYNOPSIS
    Updates the PowerShell Universal server installation via MSI.
.DESCRIPTION
#>

$MAINT_DIR      = 'D:\PSUMaint'                                     # Folder where installers, backups, logs will be stored.
$BACKUP_NAME    = "PsuBackup-$(Get-Date -Format 'yyyy-MM-dd').zip"  # Name of the zip file to create during backup
$LOG_TO_CONSOLE = $true                                             # $true/$fale - whether to log to console AND file ($true)
                                                                    # or just file ($false)


#
# DO NOT EDIT BELOW THIS LINE
#
$MaintFolders = @('logs', 'installers', 'backups')
$MaintFolders | Foreach-Object { 
    $target = (Join-Path $MAINT_DIR $_)
    if (-not(Test-Path $target)) {
        $null = New-Item $target -ItemType Directory
    }
}
. (Join-Path -Path $PSScriptRoot -ChildPath 'Public\Write-Log.ps1')
$PSDefaultParameterValues = @{
    'Write-Log:Path'        = (Join-Path $MAINT_DIR 'logs\update-log.log')
    'Write-Log:Level'       = 'INF'
    'Write-Log:ToConsole'   = $LOG_TO_CONSOLE
}
Write-Log -Message ("Starting PowerShell Universal upgrade...")

$msi = Get-Item "$MAINT_DIR\installers\PowerShellUniversal*.msi" | Sort-Object -Property LastWriteTime -Descending | Select-Object -First 1
$ver = ($msi.BaseName).split('.',2)[1]


Write-Log -Message ("Found PowerShell Universal installer version {0}: {1}" -f $ver, $msi.FullName)

$yes        = New-Object System.Management.Automation.Host.ChoiceDescription '&Yes', 'Yes'
$no         = New-Object System.Management.Automation.Host.ChoiceDescription '&No', 'No'
$options    = [System.Management.Automation.Host.ChoiceDescription[]]($yes, $no)
$title      = 'Upgrade Prompt'
$message    = ('Install version {0} of PowerShell Universal?' -f $ver)
$result     = $host.ui.PromptForChoice($title, $message, $options, 0)

if ($result -ne 0) {
    Write-Log -Message 'Cancelling upgrade operations.'
    return 1
}

$PSUSettingsPath = (Join-Path -Path $env:ProgramData -ChildPath '\PowerShellUniversal\appsettings.json')
if (-not (Test-Path $PSUSettingsPath)) {
    $PSUSettingsPath = Read-Host ('Unable to find appsettings at {0}. Enter path to appsettings.json' -f $PSUSettingsPath)    
}

$PSUSettings = Get-Content $PSUSettingsPath -Raw | ConvertFrom-Json -Depth 10
$PSUService  = Get-Service PowerShellUniversal -ErrorAction SilentlyContinue
if ($PSUService -and $PSUService.Username -notin @('LocalSystem','NT Authority\LocalService', 'NT AUTHORITY\NetworkService')) {
    $ServiceCred = get-credential -Message 'Enter credential for PowerShell Universal Service Account' -UserName $PSUService.Username
}

Write-Log -Message "Stopping PowerShell Universal service..."

try {
    Get-Service PowerShellUniversal | Stop-Service -Force -Verbose -ErrorAction Stop
}
catch {
    Write-Log ("Unable to stop PowerShell Universal service. Exiting.") -Level ERR
    Write-Log ("Error: {0}" -f $PSItem.Exception.Message) -level ERR
    exit
}

Write-Log -Message ('Creating backup of UniversalAutomation repository ({0})' -f $PSUSettings.Data.RepositoryPath)

try {
    Compress-Archive -Path $PSUSettings.Data.RepositoryPath -DestinationPath "$MAINT_DIR\backups\$BACKUP_NAME" -Force -ErrorAction Stop
    Compress-Archive -Path $PSUSettingsPath -DestinationPath "$MAINT_DIR\backups\$BACKUP_NAME" -Update -ErrorAction Stop
}
catch {
    Write-Log ("Unable to create backup. Aborting upgrade. Error: {0}" -f $PSItem.Exception.Message) -Level ERR
    exit
}

$RepoFolder         = $PSUSettings.Data.RepositoryPath
$ConnectionString   = $PSUSettings.Data.ConnectionString
$InstallLog         = "{0}\logs\{1}-install.log" -f $MAINT_DIR, $msi.Name

if ($ServiceCred) {
    $ServiceAccount = $($ServiceCred.username)
    $ServiceAccountPW = $($ServiceCred.getnetworkcredential().password)
    Write-Log -Message "Executing msiexec with Service Account configuration..."
    Write-Log -Message "Msi log: $InstallLog"
    msiexec /i ("{0}" -f $msi.FullName) /q /norestart /l*v $InstallLog REPOFOLDER="$RepoFolder" CONNECTIONSTRING="$ConnectionString" SERVICEACCOUNT="$ServiceAccount" SERVICEACCOUNTPASSWORD="$ServiceAccountPW"
}
else {
    Write-Log -Message "Executing msiexec..."
    msiexec /i ("{0}" -f $msi.FullName) /q /norestart /l*v $InstallLog REPOFOLDER="$RepoFolder" CONNECTIONSTRING="$ConnectionString"
}


Start-Sleep -Seconds 4
$message    = "Would you like to open the installation log? This will open in a new window."
$result     = $host.ui.PromptForChoice($title, $message, $options, 0)

if ($result -eq 0) {
    Write-Log -Message "Opening log file for monitoring.."
    $sb = [scriptblock]::Create(('Get-Content -Path {0} -tail 20 -wait' -f $InstallLog))
    $count = 0
    while ((-not (Test-Path $InstallLog)) -or ($count -eq 15)) {
        Write-Log -Message 'Waiting for log file...'
        $count++
        Start-Sleep -Seconds 2
    }
    Start-Process pwsh.exe -ArgumentList ('-Command {0}' -f $sb.Ast.ToString())
}
else {
    Write-Log -Message ('MSI installation will happen in the background. Installation log: {0}' -f $InstallLog)
}