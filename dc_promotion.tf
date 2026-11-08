locals {
  promote_script = <<-EOT
    $ErrorActionPreference = 'Stop'
    $log = 'C:\promote-dc.log'
    Remove-Item $log -Force -ErrorAction SilentlyContinue
    function Write-Log($msg) { Add-Content -Path $log -Value ("{0}  {1}" -f (Get-Date -Format s), $msg) }

    try {
      if ((Get-CimInstance Win32_ComputerSystem).DomainRole -ge 4) {
        Write-Log 'Already a domain controller - nothing to do.'
        exit 0
      }
      Write-Log 'Installing the AD DS role'
      Install-WindowsFeature -Name AD-Domain-Services -IncludeManagementTools | Out-Null
      Write-Log 'Promoting to a new forest'
      $safe = ConvertTo-SecureString '${random_password.admin.result}' -AsPlainText -Force
      Install-ADDSForest -DomainName '${var.domain_name}' -DomainNetbiosName '${var.domain_netbios}' -SafeModeAdministratorPassword $safe -InstallDns -NoRebootOnCompletion -Force | Out-Null
      Write-Log 'Promotion finished - restarting in 30 seconds'
      shutdown.exe /r /t 30 /c "AD DS promotion finished - restarting"
    } catch {
      Write-Log ('FAILED: ' + $_.Exception.Message)
      exit 1
    }
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
