# provider 구독 설정을 위한 variable 선언
# variable "subscription_id" {
#   type        = string
#   description = "배포 대상 구독 ID"
# }

variable "storage_accounts" {
  type = map(object({
    resource_group_name = string
    vnet_name            = optional(string, "")
    subnet_name          = optional(string, "")

    storage_account_config = object({
      name             = string
      tier             = optional(string)
      replication_type = optional(string)
      kind             = optional(string)
      min_tls_version  = optional(string)
      tags             = optional(map(string))
      https_traffic_only        = optional(bool)
      allow_nested_items_public = optional(bool)
    })

    private_endpoint_config = optional(object({
      name                 = string
      subresource_names    = optional(list(string))
      is_manual_connection = optional(bool)
    }))

    # principal_id: 사용자/그룹/서비스 프린시펄의 object_id (GUID)
    # role_definition_name: 빌트인 역할 표시 이름 (예: "Reader", "Contributor")
    # 주의: 실행 주체(SP)에 해당 스코프의 Owner 또는 User Access Administrator 필요
    iam = optional(map(object({
      principal_id         = string
      role_definition_name = string
    })), {})
  }))
  default = {}

  validation {
    condition = alltrue(flatten([
      for gw in var.storage_accounts : [
        for a in gw.iam :
        can(regex("^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$", a.principal_id))
      ]
    ]))
    error_message = "IAM의 principal_id는 object_id(GUID) 형식이어야 합니다. UPN(이메일)이 아닌 GUID를 넣어야 합니다."
  }
}
