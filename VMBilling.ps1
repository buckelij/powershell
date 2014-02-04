echo "VMBilling.ps1 : Generates a list of VMs sorted by the Folder 
      they reside in and saves the output as a CSV to $home. 

      Requires the VMWare PowerCLI Snapin.
      
      You may be prompted for credentials to access VCenter."

# Elijah Buck  - 4Feb2014 - Initial revision
	  
Add-PSSnapin VMware.VimAutomation.Core

if ( (Get-PowerCLIConfiguration -Scope User).InvalidCertificateAction -eq $null ) {
  Set-PowerCLIConfiguration -InvalidCertificateAction Ignore -Scope User
}

Connect-VIServer -Server vcenter.example.com
$exportPath = "$home\VMBilling-$((get-date -Format s) -replace ':',".").csv"
$vms = get-vm
$vmexport = $vms | select Name,Folder,@{ name="DataCenter"; expression = {Get-DataCenter -VM $_}},`
                          MemoryGB,NumCPU,`
                          @{name="diskGB"; expression = {[math]::floor($_.ProvisionedSpaceGB)}}`
                          ,PowerState
$vmexport | Sort Folder | Export-CSV -Path $exportPath -Encoding ASCII
