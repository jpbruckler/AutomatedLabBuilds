<#
    This script will build an Active Directory lab environment with a simple PKI
    on Windows Server 2022.

    It will create a domain controller, 2 member servers, and a Windows 11 client.

    1 member server will be a Root CA Server
    1 member server will have PowerShell Universall installed and configured.
#>

$AlName         = 'psudev'
$DomainName     = 'psudev.local'
$InstallUser    = 'Install'
$InstallPW      = 'gulf-tango-delta'


# Create an empty lab template, define the network and domain, and set the installation credentials
New-LabDefinition -Name $AlName -DefaultVirtualizationEngine HyperV
Add-LabDomainDefinition -Name $DomainName -AdminUser $InstallUser -AdminPassword $InstallPW
Set-LabInstallationCredential -Username $InstallUser -Password $InstallPW

Add-LabVirtualNetworkDefinition -Name $AlName -AddressSpace 192.168.77.0/24 -HyperVProperties @{ SwitchType = 'External'; AdapterName = 'Wi-Fi' }


# defining default parameter values, as these ones are the same for all the machines
$PSDefaultParameterValues = @{
    'Add-LabMachineDefinition:Network'          = $AlName
    'Add-LabMachineDefinition:ToolsPath'        = "$labSources\Tools"
    'Add-LabMachineDefinition:DnsServer1'       = '192.168.77.10'
    'Add-LabMachineDefinition:Memory'           = 1GB
    'Add-LabMachineDefinition:DomainName'       = $DomainName
    'Add-LabMachineDefinition:OperatingSystem'  = 'Windows Server 2022 Datacenter Evaluation (Desktop Experience)'
}

# Create Root Domain Controller
$postInstall = Get-LabPostInstallationActivity -ScriptFileName 'PrepPSUDevDC.ps1' -DependencyFolder $labSources\PostInstallationActivities\PsuDev\Domain
Add-LabMachineDefinition -Name 'SVR-DC-01' -Roles RootDC -IpAddress 192.168.77.10 -PostInstallationActivity $postInstall

# Create CA Root Server
$roleCaRoot = Get-LabMachineRoleDefinition -Role CaRoot @{
    CACommonName        = 'PsuDevRootCA1'
    KeyLength           = '4096'
    ValidityPeriod      = "Yearss"
    ValidityPeriodUnits = "20"
}
Add-LabMachineDefinition -Name 'SVR-CA-01' -Roles $roleCaRoot -IpAddress 192.168.77.20 

# Create Subordinate CA Server
$role = Get-LabMachineRoleDefinition -Role CaSubordinate @{
    CACommonName        = 'PsuDevSubCA1'
    KeyLength           = '2048'
    ValidityPeriod      = 'Years'
    ValidityPeriodUnits = '8' 
}
Add-LabMachineDefinition -Name 'SVR-CA-02' -IpAddress 192.168.77.21 -Roles $role

# Create PowerShell Universal Member Server
Add-LabDiskDefinition -Name DataDrive -DiskSizeInGb 100 -Label Data -DriveLetter D -AllocationUnitSize 64kb
Add-LabMachineDefinition -Name 'SVR-PSU-01' -IpAddress 192.168.77.30 -Memory 4GB -DiskName DataDrive

# Create Windows 11 Client
Add-LabMachineDefinition -Name 'END-WIN11-01' -OperatingSystem 'Windows 11 Pro'


#Install-Lab -NetworkSwitches -BaseImages -VMs #-Verbose
#Install-Lab -Domains -Verbose
#Install-Lab -CA #-Verbose
Install-Lab #-Verbose

Enable-LabCertificateAutoenrollment -Computer -User -CodeSigning
Show-LabDeploymentSummary -Detailed