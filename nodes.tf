resource "azurerm_network_interface" "node" {
  for_each            = var.node_names
  name                = "nic-${lower(each.key)}"
  location            = azurerm_resource_group.lab.location
  resource_group_name = azurerm_resource_group.lab.name

  ip_configuration {
    name                          = "ipconfig1"
    subnet_id                     = azurerm_subnet.nodes.id
    private_ip_address_allocation = "Static"
    private_ip_address            = each.value
  }
}

resource "azurerm_windows_virtual_machine" "node" {
  for_each              = var.node_names
  name                  = each.key
  computer_name         = each.key
  location              = azurerm_resource_group.lab.location
  resource_group_name   = azurerm_resource_group.lab.name
  size                  = var.vm_size
  admin_username        = var.admin_username
  admin_password        = random_password.admin.result
  network_interface_ids = [azurerm_network_interface.node[each.key].id]

  os_disk {
    name                 = "osdisk-${lower(each.key)}"
    caching              = "ReadWrite"
    storage_account_type = "StandardSSD_LRS"
  }

  source_image_reference {
    publisher = "MicrosoftWindowsServer"
    offer     = "WindowsServer"
    sku       = "2022-datacenter-g2"
    version   = "latest"
  }
}

resource "azurerm_dev_test_global_vm_shutdown_schedule" "node" {
  for_each              = var.node_names
  virtual_machine_id    = azurerm_windows_virtual_machine.node[each.key].id
  location              = azurerm_resource_group.lab.location
  enabled               = true
  daily_recurrence_time = var.shutdown_time
  timezone              = var.shutdown_timezone

  notification_settings {
    enabled = false
  }
}

resource "time_sleep" "wait_for_dc" {
  depends_on      = [azurerm_virtual_machine_extension.dc01_promote]
  create_duration = "5m"
}

resource "azurerm_virtual_machine_extension" "node_join" {
  for_each             = var.node_names
  name                 = "join-domain"
  virtual_machine_id   = azurerm_windows_virtual_machine.node[each.key].id
  publisher            = "Microsoft.Compute"
  type                 = "JsonADDomainExtension"
  type_handler_version = "1.3"

  settings = jsonencode({
    Name    = var.domain_name
    User    = "${var.domain_netbios}\\${var.admin_username}"
    Restart = "true"
    Options = "3"
  })

  protected_settings = jsonencode({
    Password = random_password.admin.result
  })

  depends_on = [time_sleep.wait_for_dc]
}
