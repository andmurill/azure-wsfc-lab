output "resource_group_name" {
  value = azurerm_resource_group.lab.name
}

output "subnet_id" {
  value = azurerm_subnet.nodes.id
}

output "dc01_public_ip" {
  value = azurerm_public_ip.dc01.ip_address
}

output "dc01_private_ip" {
  value = azurerm_network_interface.dc01.private_ip_address
}

output "admin_username" {
  value = var.admin_username
}

output "admin_password" {
  value     = random_password.admin.result
  sensitive = true
}

output "witness_account_name" {
  value = azurerm_storage_account.witness.name
}

output "witness_account_key" {
  value     = azurerm_storage_account.witness.primary_access_key
  sensitive = true
}
