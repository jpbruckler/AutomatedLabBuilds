Import-Module -Name ActiveDirectory

if (-not (Get-Command -Name Get-ADReplicationSite -ErrorAction SilentlyContinue))
{
    Write-ScreenInfo 'The script "PrepareRootDomain.ps1" script runs only if the ADReplication cmdlets are available' -Type Warning
    return
}

# Create log folder if it doesn't exist
$logFolder = 'C:\lablogs'
if (-not (Test-Path -Path $logFolder))
{
    New-Item -Path $logFolder -ItemType Directory
}


$ous    = Get-Content (Join-Path $PSScriptRoot -ChildPath ous.txt)
$users  = Import-Csv (Join-Path $PSScriptRoot -ChildPath users.csv)
$groups = Import-Csv (Join-Path $PSScriptRoot -ChildPath groups.csv)
$passwd = 'gulf-tango-delta' | ConvertTo-SecureString -AsPlainText -Force

foreach ($ou in $ous) {
    try {
        Get-ADOrganizationalUnit $ou -ErrorAction Stop
        "$ou already exists" | Out-File "C:\lablogs\adddomain.log" -Append
    }
    catch {
        New-ADOrganizationalUnit -DisplayName ($ou -split ',')[0].Replace("OU=","") -Name ($ou -split ',')[0].Replace("OU=","") -Path $ou.split(',',2)[1] -Verbose
        "Creating $ou..." | Out-File "C:\lablogs\adddomain.log" -Append
    }
}

foreach ($group in $groups) {
    try {
        $null = Get-AdGroup $group.Name -ErrorAction Stop
        "$Group already exists" | Out-File "C:\lablogs\adddomain.log" -Append
    }
    catch {
        New-AdGroup -Name $group.Name -DisplayName $group.DisplayName -Path $group.Path -GroupCategory Security -GroupScope Global -Verbose
        "Creating $Group..." | Out-File "C:\lablogs\adddomain.log" -Append
    }
}

# Create basic accounts. Normal users will be created later.
$LabAccounts = @(
    [PSCustomObject]@{
        Name = 'BigBoss'
        Password = $passwd
        Description = 'Domain and Enterprise Adminsitrator'
        Groups = @('Domain Admins', 'Enterprise Admins')
        Path = 'OU=SecuredAccounts,OU=Secured,DC=psudev,DC=local'
    },
    [PSCustomObject]@{
        Name = 'PsuAdmin'
        AccountPassword = $passwd
        Description = 'PowerShell Universall Application admin'
        Groups = @('APP-PSU-Admins')
        Path = 'OU=Users,DC=psudev,DC=local'
    },
    [PSCustomObject]@{
        Name = 'PsuUser'
        Password = $passwd
        Description = 'PowerShell Universall Application user'
        Groups = @('APP-PSU-Users')
        Path = 'OU=Users,DC=psudev,DC=local'
    },
    [PSCustomObject]@{
        Name = 'PsuService'
        Password = $passwd
        Description = 'Service account for PowerShell Universal'
        Groups = @()
        Path = 'OU=Service Accounts,DC=psudev,DC=local'
    }
)

foreach ($account in $LabAccounts) {
    try {
        $null = Get-AdUser $account.Name -ErrorAction Stop
        "$($account.Name) already exists" | Out-File "C:\lablogs\adddomain.log" -Append
    }
    catch {
        $u = New-AdUser -Name $account.Name -AccountPassword $account.Password -Description $account.Description -Path $account.Path
        
        foreach ($group in $account.Groups) {
            Add-AdGroupMember -Identity $group -Members $u
        }
        "Created $($account.Name)..." | Out-File "C:\lablogs\adddomain.log" -Append
    }
}


# Create normal users
foreach ($user in $users) {
    try {
        $null = Get-AdUser $user.Name -ErrorAction Stop
        "$($user.Name) already exists" | Out-File "C:\lablogs\adddomain.log" -Append
    }
    catch {
        $u = New-AdUser -Name $user.Name -AccountPassword $user.Password -State $user.State -StreetAddress $user.StreetAddress -City $user.City -Country $user.Country -Initials $user.MiddleInitial -UserPrincipalName $user.EmailAddress -Department $user.Department -Path $user.Path
        
        foreach ($group in $user.Groups) {
            Add-AdGroupMember -Identity $group -Members $u
        }
        "Created $($user.Name)..." | Out-File "C:\lablogs\adddomain.log" -Append
    }
}