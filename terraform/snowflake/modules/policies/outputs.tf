output "database_name" {
  description = "The name of the policies database"
  value       = snowflake_database.policies.name
}


output "user_password_policy_name" {
  description = "Fully qualified name of the user password policy"
  value       = snowflake_password_policy.user_password_policy.fully_qualified_name
}


output "external_duo_mfa_policy_name" {
  description = "Fully qualified name of the external Duo MFA authentication policy"
  value       = snowflake_authentication_policy.external_duo_mfa.fully_qualified_name
}


output "service_account_keypair_policy_name" {
  description = "Fully qualified name of the service account keypair authentication policy"
  value       = snowflake_authentication_policy.service_account_keypair.fully_qualified_name
}


output "legacy_service_password_policy_name" {
  description = "Fully qualified name of the legacy service password authentication policy"
  value       = snowflake_authentication_policy.legacy_service_password.fully_qualified_name
}

output "odi_okta_only_policy_name" {
  description = "Fully qualified name of the ODI Okta-only authentication policy (null if disabled)"
  value       = length(snowflake_authentication_policy.odi_okta_only) > 0 ? snowflake_authentication_policy.odi_okta_only[0].fully_qualified_name : null
}

output "admin_okta_duo_policy_name" {
  description = "Fully qualified name of the admin Okta-duo authentication policy (null if disabled)"
  value       = length(snowflake_authentication_policy.admin_okta_duo) > 0 ? snowflake_authentication_policy.admin_okta_duo[0].fully_qualified_name : null
}
