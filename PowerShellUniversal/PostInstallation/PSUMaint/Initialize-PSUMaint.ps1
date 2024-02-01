$MAINT_DIR      = 'D:\PSUMaint'
$MaintFolders   = @('logs', 'installers', 'backups')
$MaintFolders | Foreach-Object { 
    $target = (Join-Path $MAINT_DIR $_)
    if (-not(Test-Path $target)) {
        $null = New-Item $target -ItemType Directory
    }
}