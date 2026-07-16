data "azurerm_resource_group" "rg" {
  for_each = toset([for k, v in var.storage_accounts : v.resource_group_name])
  name     = each.key
}

data "azurerm_subnet" "subnet" {
  for_each = {
    for k, v in var.storage_accounts : k => v
    if v.subnet_name != "" && v.vnet_name != ""
  }

  name                 = each.value.subnet_name
  virtual_network_name = each.value.vnet_name
  resource_group_name  = data.azurerm_resource_group.rg[each.value.resource_group_name].name
}
