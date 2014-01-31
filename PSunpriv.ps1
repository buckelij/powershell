Notes on using standard-users to deploy code and start and stop services in Windows.

## PowerShell Remoting configuration ##

This assumes that PowerShell remoting has been enabled and is working for the administrator account.

    # This script modifies the WinRM top-level SDDL definition and the PowerShell plugin SDDL 
    # definition to allow PowerShell Remoting access to members of the PSRemote_ group. 
    #
    # In Server 2012, these changes are not required because there is a 'Remote Management Users' group built-in. 
    #
    # Elijah Buck 28Jan2013
    #
   
    $computer = "server1.dmz.example.com" #The remote server to be configured
    $creds = Get-Credential administrator #The local administrator account of the remote computer
    $OSversion = Invoke-Command -Computer $computer -Cred $creds -ScriptBlock { [Environment]::OSVersion.Version }
   
    #Create a new group 'PSremote_' and return its SID
    if ( $OSversion -lt (new-object 'Version' 6,2) ) {  #2k12 and up have a builtin group for this
      $PSremoteSID = Invoke-Command -Computer $computer -Cred $creds -ScriptBlock {
                                    $ADSIobj = [ADSI]"WinNT://localhost"
                                    $ADSIGroup = $ADSIobj.Create("Group","PSremote_")
                                    $ADSIGroup.SetInfo()
                                    $ADSIGroup.description = "Grants non-admin users access to powershell remoting"
                                    $ADSIGroup.SetInfo()
                                    $PSremoteGroup = New-object system.security.principal.NTAccount("PSremote_")
                                    $PSremoteGroup.Translate([System.security.principal.securityidentifier]) #returns SID
                     }
      $PSremoteACE = "(A;;GA;;;$PSremoteSID)"
      
      #Set RootSDDL for WINRM, providing top-level access to the listener
      Connect-WSMan -computer $computer -cred $creds
      $RootSDDL = Get-ChildItem WSMAN::$computer\Service\RootSDDL
      $newSDDL = $RootSDDL.Value -replace "\)S:P",")${PSremoteACE}S:P"
      Set-Item -Path WSMAN::$computer\Service\RootSDDL -Value $newSDDL -Force
     
      #Set SDDL for the powershell plugin
      if ( $OSversion -ge (new-object 'Version' 6,0) ) { #don't need to set powershell SDDL for 2k3
       $WinRMmspowershell = (Get-ChildItem `
              wsman::$computer\Plugin\microsoft.powershell\Resources\Resource*\Security\Security*\SDDL).PSParentPath
       $newPSSDDL = (Get-ChildItem $WinRMmspowershell\SDDL).Value -Replace "\)S:P",")${PSremoteACE}S:P"
       Set-Item -Path $WinRMmspowershell\SDDL -Value $newPSSDDL -Force
      }
    }


## deploy_ group Service and FileSystem access ##

Each Windows service has a Security Descriptor (SDDL - Security Descriptor Definition Language) that controls access to the service actions. In the example below, we grant the group 'deploy_' full access to the 'tomcat7' service. Members of that group can then run the PowerShell commands 'Stop-Service tomcat7', 'Start-Service tomcat7', and 'Get-Service smtpsvc' to control the service.

    Invoke-Command -Computer $computer -Cred $creds -ScriptBlock {
      $DeployGroup = New-object system.security.principal.NTAccount("deploy_")
      $DeploySid = $DeployGroup.Translate([System.security.principal.securityidentifier])
      $servicesddl = sc.exe sdshow tomcat7
      $newservicesddl = $servicesddl -replace "\)S:",")(A;;CCLCSWRPWPDTLOCRRC;;;${DeploySID})S:"
      sc.exe sdset tomcat7 $newservicesddl
    }


The deploy_ group will also probably want to be able to write to the appropriate directories:

    Invoke-Command -Computer $computer -Cred $creds -ScriptBlock {
      icacls.exe D:\Tomcat7\webapps /grant 'deploy_:(F)'
    }

Sample Deployment Script

  $computer = "server1.dmz.example.com"
  $encpass = ConvertTo-SecureString "THEPASS" -AsPlainText -Force
  $creds = New-Object System.Management.Automation.PSCredential("deploy",$encpass)
  #this requires PS 3+
  new-psdrive -name JDEST -PSProvider FileSystem -cred $creds -root \\${computer}\deploytemp
  copy-item c:\build\proj\ROOT.war JDEST:\
  invoke-command -Computer $computer -Cred $creds -ScriptBlock {
    Stop-Service tomcat7 
    delete-item d:\Tomcat7\webapps\ROOT.war
    copy-item d:\deploytemp\ROOT.war d:\Tomcat7\webapps\ROOT.war
    Start-Service tomcat7
  }
