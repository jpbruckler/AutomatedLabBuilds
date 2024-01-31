<#
    This script will build an Active Directory lab environment with a simple PKI
    on Windows Server 2022.

    It will create a domain controller, 2 member servers, and a Windows 11 client.

    1 member server will be a Root CA Server
    1 member server will have PowerShell Universall installed and configured.
#>

$labName        = 'psudev'
$labDomain      = 'psudev.local'
$labInstallUser = 'Install'
$labInstallPW   = 'gulf-tango-delta'


# Create an empty lab template, define the network and domain, and set the installation credentials
New-LabDefinition -Name $labName -DefaultVirtualizationEngine HyperV
Add-LabDomainDefinition -Name $labDomain -AdminUser $labInstallUser -AdminPassword $labInstallPW
Set-LabInstallationCredential -Username $labInstallUser -Password $labInstallPW

Add-LabVirtualNetworkDefinition -Name $labName -AddressSpace 192.168.77.0/24
Add-LabVirtualNetworkDefinition -Name 'Default Switch' -HyperVProperties @{ SwitchType = 'External'; AdapterName = 'Wi-Fi' }


# defining default parameter values, as these ones are the same for all the machines
$PSDefaultParameterValues = @{
    'Add-LabMachineDefinition:Network' = $labName
    'Add-LabMachineDefinition:ToolsPath'= "$labSources\Tools"
    'Add-LabMachineDefinition:DnsServer1'= '192.168.77.10'
    'Add-LabMachineDefinition:Gateway' = '192.168.77.10'
    'Add-LabMachineDefinition:Memory'= 1GB
    'Add-LabMachineDefinition:DomainName'= $labDomain
    'Add-LabMachineDefinition:OperatingSystem'= 'Windows Server 2022 Datacenter Evaluation (Desktop Experience)'
}

# Create Root Domain Controller
$postInstall = Get-LabPostInstallationActivity -ScriptFileName 'PrepPSUDevDC.ps1' -DependencyFolder $labSources\PostInstallationActivities\PsuDev\Domain
$netAdapter = @()
$netAdapter += New-LabNetworkAdapterDefinition -VirtualSwitch $labName -Ipv4Address 192.168.77.10
$netAdapter += New-LabNetworkAdapterDefinition -VirtualSwitch 'Default Switch' -UseDhcp
Add-LabMachineDefinition -Name 'SVR-DC-01' -Roles RootDC,Routing -NetworkAdapter $netAdapter -PostInstallationActivity $postInstall

# Create CA Root Server
$roleCaRoot = Get-LabMachineRoleDefinition -Role CaRoot
Add-LabMachineDefinition -Name 'SVR-CA-01' -Roles $roleCaRoot -IpAddress 192.168.77.20 

# Create Subordinate CA Server
$role = Get-LabMachineRoleDefinition -Role CaSubordinate
Add-LabMachineDefinition -Name 'SVR-CA-02' -IpAddress 192.168.77.21 -Roles $role

# Create PowerShell Universal Member Server
Add-LabMachineDefinition -Name 'SVR-PSU-01' -IpAddress 192.168.77.30 -Memory 4GB

# Create Windows 11 Client
Add-LabMachineDefinition -Name 'END-WIN11-01' -OperatingSystem 'Windows 11 Pro'


Install-Lab -NetworkSwitches -BaseImages -VMs
Install-Lab -Domains
Install-Lab -CA
Install-Lab

Enable-LabCertificateAutoenrollment -Computer -User -CodeSigning
Show-LabDeploymentSummary -Detailed