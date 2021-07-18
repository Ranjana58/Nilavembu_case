$rg1='nilavemburg1SEA'
$loc1='southeast asia'

New-AzResourceGroup `
    -Name $rg1 `
    -location $loc1

New-AzAvailabilitySet `
    -location $loc1 `
    -Name "SEAavailabilitySet" `
    -ResourceGroupName "$rg1" `
    -Sku aligned `
    -PlatformFaultDomainCount 2 `
    -PlatformUpdateDomainCount 2

$sn1=New-AzVirtualNetworkSubnetConfig -Name 'seasubnet1' -AddressPrefix '10.10.1.0/24'

$vNet1=New-AzVirtualNetwork -ResourceGroupName $rg1 -Name ‘seavnet1’ -location $loc1 -AddressPrefix '10.10.0.0/16' -Subnet $sn1

$rule1 = New-AzNetworkSecurityRuleConfig -Name web-rule1 -Description "Allow HTTP" `
     -Access Allow -Protocol Tcp -Direction Inbound -Priority 1001 -SourceAddressPrefix Internet -SourcePortRange * -DestinationAddressPrefix * -DestinationPortRange 80

$rule2 = New-AzNetworkSecurityRuleConfig -Name web-rule2 -Description "Allow HTTPS" `
     -Access Allow -Protocol Tcp -Direction Inbound -Priority 1002 -SourceAddressPrefix Internet -SourcePortRange * -DestinationAddressPrefix * -DestinationPortRange 443

$nsg1 = New-AzNetworkSecurityGroup -ResourceGroupName $rg1 -location $loc1 -Name `
     "seaNSG" -SecurityRules $rule1,$rule2

Set-AzVirtualNetworkSubnetConfig -VirtualNetwork $vNet1 -Name ‘seasubnet1’ -AddressPrefix '10.10.1.0/24' -NetworkSecurityGroup $nsg1

$cred = Get-Credential

$size='Standard_D2ds_v4'

for ($i=1; $i -le 2; $i++)
 {
New-AzVM `
 -ResourceGroupName "nilavemburg1SEA" `
 -Name "myVM$i" `
 -Location 'Southeast Asia' `
 -Size "$size" `
 -VirtualNetworkName "seavnet1" `
 -SubnetName "seasubnet1" `
 -SecurityGroupName "seaNSG" `
 -AvailabilitySetName "SEAavailabilitySet" `
 -Credential $cred
 }

for ($i=1; $i -le 2; $i++)
 {
Set-AzVMExtension -ResourceGroupName "$nilavemburg1SEA" `
    -ExtensionName "IIS" `
    -VMName "myVM$i" `
    -location "$southeast asia" `
    -Publisher Microsoft.Compute `
    -ExtensionType CustomScriptExtension `
    -TypeHandlerVersion 1.8 `
    -SettingString '{"commandToExecute":"powershell Add-WindowsFeature Web-Server; powershell Add-Content -Path \"C:\\inetpub\\wwwroot\\Default.htm\" -Value $($env:computername)"}'
 }



 

$lbPIP=New-AzPublicIpAddress -ResourceGroupName "nilavemburg1SEA" `
		-Name sealbPIP `
        -Location "southeast asia" -Sku Standard `          
        -AllocationMethod Static
		
$feIP=New-AZLoadBalancerFrontendIPconfig -name FIP -PublicIpAddress $lbPIP
		
$bePool=New-AzLoadBalancerBackendAddressPoolConfig -Name seaLBbp

$hprobe1=New-AzLoadBalancerProbeConfig -Name probe_http `
                              -Protocol http `
                              -Port 80 `
                              -IntervalInSeconds 5 -RequestPath 'HealthProbe.aspx' `
                              -ProbeCount 2
	
$hprobe2=New-AzLoadBalancerProbeConfig -Name probe_https `
                              -Protocol https `
                              -Port 443 `
                              -IntervalInSeconds 5 -RequestPath 'HealthProbe.aspx' `
                              -ProbeCount 2
							  
$lbrule1=New-AzLoadBalancerRuleConfig -Name lbrule_80 `
                             -Protocol TCP `
                             -FrontendPort 80 `
                             -FrontendIpConfiguration $feIP `
                             -BackendPort 80 `
                             -BackendAddressPool $bePool `
                             -Probe $hprobe1 `
			                 -LoadDistribution SourceIPProtocol
							 
$lbrule2=New-AzLoadBalancerRuleConfig -Name lbrule_443 `
                             -Protocol TCP `
                             -FrontendPort 443 `
                             -FrontendIpConfiguration $feIP `
                             -BackendPort 443 `
                             -BackendAddressPool $bePool `
                             -Probe $hprobe2 `
			                 -LoadDistribution SourceIPProtocol


New-AzLoadBalancer -ResourceGroupName "nilavemburg1SEA" `
   -Name lbSEA -Location "southeast asia" -Sku Standard  `
   -FrontendIpConfiguration $feIP -BackendAddressPool $bePool `
   -Probe $hprobe1,$hprobe2 -LoadBalancingRule $lbrule1,$lbrule2




