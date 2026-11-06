terraform {
  backend "azurerm" {
    resource_group_name  = "rg-tfstate"
    storage_account_name = "sttfstate52208"
    container_name       = "tfstate"
    key                  = "wsfc-lab.tfstate"
  }
}
