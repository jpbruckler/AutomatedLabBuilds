function Write-Log {
    <#
    .SYNOPSIS
        Write a log message to a log file.

    .DESCRIPTION
        This function writes a log message with a timestamp to a log file.
        The log level must be one of the following: INF, WRN, ERR, DBG, VRB.

    .PARAMETER Message
        The log message to write to the file.

    .PARAMETER Level
        The level of the log message. Must be one of the following: INF, WRN, ERR, DBG, VRB.

    .PARAMETER Path
        The path to the log file. Defaults to "log.txt" in the current directory.

    .EXAMPLE
        Write-Log -Message "This is a debug message" -Level DBG

        Writes a debug message to the log.txt file.

    .EXAMPLE
        Write-Log -Message "This is an error message" -Level ERR -LogFile "C:\Logs\mylog.txt"

        Writes an error message to the specified log file.
    #>
    param (
        [Parameter(Mandatory = $false)]
        [string] $Message,

        [Parameter(Mandatory=$true)]
        [ValidateSet("INF","WRN","ERR","DBG","VRB")]
        [string] $Level,

        [string] $Path = "log.txt",

        [int] $Indent = 0,

        [switch] $ToConsole
    )

    if ([string]::IsNullOrWhiteSpace($Message)) { return }
    if ($Level -eq 'DBG' -and $DebugPreference -ne 'Continue') { return }

    if ($Indent -gt 0) {
        $Tab = ' ' * (4 * $Indent)
    }
    else {
        $Tab = ''
    }
    try {
        Resolve-Path $Path -ErrorAction Stop | Out-Null
    }
    catch {
        New-Item -Path $Path -ItemType File -Force | Out-Null
    }

    # Current timestamp
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss.fff K"

    # Compose the log message using formatted string
    $MessageData = "{0} [{1}] {2}{3}" -f $timestamp, $Level, $Tab, $Message

    if ($ToConsole) {
        Write-Information -MessageData $MessageData -Tags 'IdentityManagement' -InformationAction Continue
    }

    # Write the log message to the log file
    Write-Information -MessageData $MessageData -Tags 'IdentityManagement' 6>> $Path
}
