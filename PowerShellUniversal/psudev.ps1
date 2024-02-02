$labName    = 'psudev'
$labDomain  = 'psudev.local'
$labUser    = 'Install'
$labPW      = 'gulf-tango-delta'
$labNet     = '172.30.30.0/24'


## Setup a NAT if one doesn't exist
#$nats = Get-NetNat
#
#if ($null -eq $nats) {
#    Write-ScreenInfo -Message "No NATs defined. Creating NAT for $labNet." -TaskStart
#    try {
#        New-NetNat -Name 'NAT' -InternalIPInterfaceAddressPrefix $labNet -ErrorAction Stop
#    }
#    catch {
#        Write-ScreenInfo -Type Error -Message "Failed to create NAT for $labNet."
#        Write-ScreenInfo -Type Error -Message $_.Exception.Message -TaskEnd
#        break;
#    }
#}
#else {
#    if ($nats.InternalIPInterfaceAddressPrefix -like "$labSubnet*") {
#        Write-ScreenInfo -Message "NAT for $labNet already exists." -TaskEnd
#    }
#    else {
#        Write-ScreenInfo -Type Warning -Message "NATs exist, but none for $labNet. Windows can only support 1 NAT at a time."
#        Write-ScreenInfo -Type Warning -Message "Please remove the existing NATs and re-run the script." -TaskEnd
#        break;
#    }
#}

New-LabDefinition -Name $labName -DefaultVirtualizationEngine HyperV
Add-LabDomainDefinition -Name $labDomain -AdminUser $labUser -AdminPassword $labPW
Add-LabVirtualNetworkDefinition -Name $labName -AddressSpace $labNet -HyperVProperties @{ SwitchType = 'Internal' }
Add-LabVirtualNetworkDefinition -Name 'Default Switch' -HyperVProperties @{ SwitchType = 'External'; AdapterName = 'Wi-Fi' }



$PSDefaultParameterValues = @{
    'Add-LabMachineDefinition:Network'          = $labName
    'Add-LabMachineDefinition:ToolsPath'        = "$labSources\Tools"
    'Add-LabMachineDefinition:DomainName'       = $labDomain
    'Add-LabMachineDefinition:DnsServer1'       = '172.30.30.10'
    'Add-LabMachineDefinition:Gateway'          = '172.30.30.10'
    'Add-LabMachineDefinition:OperatingSystem'  = 'Windows Server 2022 Datacenter Evaluation (Desktop Experience)'
}


$netAdapter = @()
$netAdapter += New-LabNetworkAdapterDefinition -VirtualSwitch $labName -Ipv4Address 172.30.30.10
$netAdapter += New-LabNetworkAdapterDefinition -VirtualSwitch 'Default Switch' -UseDhcp
Add-LabMachineDefinition -Name PSU-DC-01 -Memory 1GB -Roles RootDC, Routing -NetworkAdapter $netAdapter 

Add-LabDiskDefinition -Name DataDrive -DiskSizeInGb 100 -Label Data -DriveLetter D -AllocationUnitSize 64kb
Add-LabMachineDefinition -Name 'SVR-PSU-01' -IpAddress 172.30.30.30 -Memory 4GB -DiskName DataDrive

Install-Lab
Show-LabDeploymentSummary -Detailed