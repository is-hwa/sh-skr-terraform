terraform {
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "4.74.0"
    }
  }
  backend "local" {}
}

provider "azurerm" {
  features {}
  # 복수의 구독에 대해 배포를 해야되는 환경에서는 관리 그룹으로 service connection을 만들고 작업마다 subscription id를 지정해야함
  # subscription_id = var.subscription_id
}
