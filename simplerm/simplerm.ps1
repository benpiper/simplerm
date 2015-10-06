# PowerShell script to create OVA files from VMs

Function Invoke-SSHCommands {
 Param($Hostname,$Username,$Password, $CommandArray,$PlinkAndPath,$ConnectOnceToAcceptHostKey = $true)
 $Target = $Username + '@' + $Hostname
 $plinkoptions = "-ssh $Target -pw $Password"
 #Build ssh Commands
 $CommandArray += "; exit"
 $remoteCommand = ""
 $CommandArray | % { $remoteCommand += [string]::Format('{0}; ', $_)
 }
 #plist prompts to accept client host key. This section will
 #login and accept the host key then logout.
 if($ConnectOnceToAcceptHostKey)
 {
  $PlinkCommand  = [string]::Format('echo y | & "{0}" {1} exit', $PlinkAndPath, $plinkoptions )
  Write-Host $PlinkCommand
  $msg = Invoke-Expression $PlinkCommand
 }
 #format plist command
 $PlinkCommand = [string]::Format('& "{0}" {1} "{2}"', $PlinkAndPath, $plinkoptions , $remoteCommand)
 #ready to run the following command
 Write-Host $PlinkCommand
 $msg = Invoke-Expression $PlinkCommand
 $msg
}
Write-Host " "
Write-Host "Prerequisites for this script:"
Write-Host "   - Configure Powershell variables and VM array in this script"
Write-Host "   - Verify that your Portgroup exists and is configure correctly"
Write-Host "   - There are successful backups on DR side."
Write-Host " "

#Write-Host "vCenter info:"
#$vCenter      = Read-Host "   - Please enter the vCenter name? "
#$Username     = Read-Host "   - Please enter vCenter user name? "
#$Password     = Read-Host "   - Please enter vCenter user password? " -AsSecureString
#Write-Host "VM info:"
#$VMUsername   = Read-Host "   - Please enter User name with administrator rights? "
#$VMPassword   = Read-Host "   - Please enter Password for VM user? " -AsSecureString

# Login info for SSH with putty
$vCenter      = "SanJoseVC.demo.local"
$Username     = "warren@demo"
$Password     = "Simple2013"
$VMUsername   = "administrator"
$VMPassword   = "Simple2013"

$Hostname     = "10.40.21.25"
$PlinkAndPath = "C:\Program Files (x86)\PuTTY\plink.exe"

# Configure Which VMs will be recovered.
#       0,             1,          2,                 3,             4,                5,             6,               7,             8,               9,               10,    
#       VM,            Datacenter, Source Datastore,  IP,            DR VM Name,       DR Datacenter, DR Datastore,    DR PortGroup,  DR IP,           Network Mask,    Gateway
$VMarray = @(
       ("WarrenWin02", "Boston",   "SVT_Boston01",    "10.40.21.30", "WarrenWin02_DR", "SanJose",     "SVT_SanJose01", "DR_Network", "192.168.152.10", "255.255.255.0", "192.168.152.1"),
       ("JPWin01",     "Boston",   "SVT_Boston01",    "10.40.21.31", "JPWin01_DR",     "SanJose",     "SVT_SanJose01", "DR_Network", "192.168.152.11", "255.255.255.0", "192.168.152.1")
	 )

$Server = Connect-viserver -Server $vCenter -User $Username -Password $Password
write-host "Connected to $vCenter"
$VMarray | ForEach-Object {
  $SourceVM      = $_[0]
  $SourceDC      = $_[1]
  $SourceDS      = $_[2]
  $SourceIP      = $_[3]
  $DRVM          = $_[4]
  $DRDataCenter  = $_[5]
  $DRDataStore   = $_[6]
  $DRNetwork     = $_[7]
  $DRIP          = $_[8]
  $DRNetmask     = $_[9]
  $DRGateway     = $_[10]
  
  Write-Host "Restore the last backup for $SourceVM"
  $C01=". /var/tmp/build/bin/appsetup; "
  $C02='src_vm="' + "$SourceVM" + '"; '
#  $C03='src_ds="' + $SourceDS + '"; '
#  $C04='temp="$(svt-backup-show --vm $src_vm --datastore $src_ds --output xml | xpath -q -e "//CommandResult/Backup[state=4]")"; '
#  $C05='backup="$(echo ''<a>''$temp''</a>'' | xpath -q -e "//Backup[not(../Backup/timestamp > timestamp)]/name/text()")"; '
#  $C06='svt-backup-restore --backup $backup ' + "--datastore $SourceDS --vm $SourceVM --destination $DRDataCenter --home $DRDataStore --name $DRVM --force --output xml --wait y"
#  $Commands=$C01 + $C02 + $C03 + $C04 + $C05 + $C06
  $Commands=$C01 + $C02 + "echo "

  Invoke-SSHCommands `
   -User         $Username  `
   -Hostname     $Hostname `
   -Password     $Password `
   -PlinkAndPath $PlinkAndPath `
   -CommandArray $Commands
   
#   Write-Host "Change $DRVM Network Adapter to $DRNetwork"
#   Get-VM $DRVM | Get-NetworkAdapter | Set-NetworkAdapter -NetworkName $DRNetwork -Confirm:$false
#   Write-Host "Boot VM $DRVM"
#   Start-VM $DRVM
}

exit

Write-host "Need to wait until VMware tools starts!"
sleep 60
   
 $VMarray | ForEach-Object {
     $SourceVM      = $_[0]
     $SourceDC      = $_[1]
     $SourceDS      = $_[2]
     $SourceIP      = $_[3]
     $DRVM          = $_[4]
     $DRDataCenter  = $_[5]
     $DRDataStore   = $_[6]
     $DRNetwork     = $_[7]
     $DRIP          = $_[8]
     $DRNetmask     = $_[9]
     $DRGateway     = $_[10]
 
     Write-Host "Change IP of VM $DRVM, IP $DRIP, Netmask $DRNetmask, Gateway $DRGateway"
     Get-VMGuestNetworkInterface $DRVM -GuestUser "$VMUsername" -GuestPassword "$VMPassword" |
         Where-Object {$_.ip -ne $null}
#        Where-Object {$_.ip -eq $SourceIP}
     Get-VMGuestNetworkInterface $DRVM -GuestUser "$VMUsername" -GuestPassword "$VMPassword" |
         Where-Object {$_.ip -ne $null} |
		 Set-VMGuestNetworkInterface -IP $DRIP -netmask $DRNetmask -gateway $DRGateway -GuestUser "$VMUsername" -GuestPassword "$VMPassword"   
		 Restart-VMGuest -VM $DRVM
}

Disconnect-VIServer -Server $Server -Confirm:$false
