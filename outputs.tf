output "resource_group_name" {
  value = azurerm_resource_group.lab.name
}

output "subnet_id" {
  value = azurerm_subnet.nodes.id
}
