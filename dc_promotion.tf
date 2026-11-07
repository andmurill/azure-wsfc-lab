locals {
  promote_script = <<-EOT
    $ErrorActionPreference = 'Stop'
    Start-Transcript -Path 'C:\promote-dc.log' -Append
    if ((Get-CimInstance Win32_ComputerSystem).DomainRole -ge 4) {
      Write-Output 'Already a domain controller - nothing to do.'
      Stop-Transcript
      exit 0
    }
    Install-WindowsFeature -Name AD-Domain-Services -IncludeManagementTools | Out-Null
    $safe = ConvertTo-SecureString '${random_password.admin.result}' -AsPlainText -Force
    Install-ADDSForest -DomainName '${var.domain_name}' -DomainNetbiosName '${var.domain_netbios}' -SafeModeAdministratorPassword $safe -InstallDns -NoRebootOnCompletion -Force
    shutdown.exe /r /t 30 /c "AD DS promotion finished - restarting"
    Stop-Transcript
  EOT
}

resource "azurerm_virtual_machine_extension" "dc01_promote" {
  name                 = "promote-dc"
  virtual_machine_id   = azurerm_windows_virtual_machine.dc01.id
  publisher            = "Microsoft.Compute"
  type                 = "CustomScriptExtension"
  type_handler_version = "1.10"

  protected_settings = jsonencode({
    commandToExecute = "powershell.exe -ExecutionPolicy Bypass -EncodedCommand ${textencodebase64(local.promote_script, "UTF-16LE")}"
  })
}
