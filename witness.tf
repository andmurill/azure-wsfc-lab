resource "random_string" "witness" {
  length  = 6
  special = false
  upper   = false
}

resource "azurerm_storage_account" "witness" {
  name                            = "stwitness${random_string.witness.result}"
  resource_group_name             = azurerm_resource_group.lab.name
  location                        = azurerm_resource_group.lab.location
  account_tier                    = "Standard"
  account_replication_type        = "LRS"
  min_tls_version                 = "TLS1_2"
  allow_nested_items_to_be_public = false
}
