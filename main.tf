resource "azurerm_storage_account" "storage-account" {
  for_each = {
    for k, v in var.storage_accounts : k => v
    if v.storage_account_config.tier != null
  }

  name                      = each.value.storage_account_config.name
  resource_group_name      = data.azurerm_resource_group.rg[each.value.resource_group_name].name
  location                 = data.azurerm_resource_group.rg[each.value.resource_group_name].location
  account_tier             = each.value.storage_account_config.tier
  account_replication_type = each.value.storage_account_config.replication_type
  account_kind              = each.value.storage_account_config.kind
  min_tls_version           = each.value.storage_account_config.min_tls_version
  https_traffic_only_enabled       = each.value.storage_account_config.https_traffic_only
  allow_nested_items_to_be_public = each.value.storage_account_config.allow_nested_items_public
  # Terraform(azurerm provider)이 계정 키로 데이터 플레인에 접근하므로 반드시 true 유지
  # false로 변경 시 배포 중 403 (KeyBasedAuthenticationNotPermitted) 발생
  # false가 필요하면 provider에 storage_use_azuread = true + 데이터 플레인 RBAC 부여 선행 필요
  shared_access_key_enabled       = true
  tags = each.value.storage_account_config.tags
}

resource "azurerm_private_endpoint" "pe" {
  for_each = {
    for k, v in var.storage_accounts : k => v
    if v.storage_account_config.tier != null && v.private_endpoint_config != null
  }

  name                = each.value.private_endpoint_config.name
  location            = data.azurerm_resource_group.rg[each.value.resource_group_name].location
  resource_group_name = data.azurerm_resource_group.rg[each.value.resource_group_name].name
  subnet_id           = data.azurerm_subnet.subnet[each.key].id

  private_service_connection {
    name                           = each.value.private_endpoint_config.name
    private_connection_resource_id = azurerm_storage_account.storage-account[each.key].id
    subresource_names              = each.value.private_endpoint_config.subresource_names
    is_manual_connection           = each.value.private_endpoint_config.is_manual_connection
  }
}

# ---------------------------------------------------------------------------
# IAM 역할 할당
# 각 스토리지 계정 항목의 iam 맵을 "계정키/할당키" 단일 맵으로 평탄화해서 for_each.
# scope가 스토리지 계정 리소스를 직접 참조하므로 destroy 시 할당 -> 계정 순으로
# 정리되어 고아 롤 할당이 남지 않는다.
# 사전 조건: 실행 주체(SP)에 해당 스코프의 Owner 또는
#            User Access Administrator 역할 필요 (Contributor만으로는 403)
# ---------------------------------------------------------------------------
locals {
  storage_iam = merge([
    for sa_key, sa in var.storage_accounts : {
      for iam_key, a in sa.iam :
      "${sa_key}/${iam_key}" => {
        sa_key               = sa_key
        principal_id         = a.principal_id
        role_definition_name = a.role_definition_name
      }
    }
  ]...)
}

resource "azurerm_role_assignment" "storage" {
  for_each = local.storage_iam

  scope                = azurerm_storage_account.storage-account[each.value.sa_key].id
  role_definition_name = each.value.role_definition_name
  principal_id         = each.value.principal_id
}
