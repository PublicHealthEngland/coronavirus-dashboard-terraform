terraform {
  required_version = ">= 0.12"
  backend "azurerm" {
    resource_group_name  = "UKS-COVID19-DRE-TFSTATE"
    storage_account_name = "tfstate106"
    #container_name       = "tfstate-pubdash-dev"
    #key                  = "terraform-pub-dash-dev.tfstate"
    container_name       = "tfstate-pubdash-staging"
    key                  = "terraform-pub-dash-staging.tfstate"
  }
}