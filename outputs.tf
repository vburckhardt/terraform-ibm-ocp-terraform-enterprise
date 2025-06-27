########################################################################################################################
# Outputs
########################################################################################################################

# output "cluster_name" {
#   value       = module.ocp_fscloud.cluster_name
#   description = "The name of the provisioned cluster."
# }

output "tfe_console_url" {
  value       = module.tfe_install.tfe_console_url
  description = "The URL to access the TFE console"
}

output "tfe_hostname" {
  value       = module.tfe_install.tfe_hostname
  description = "The hostname for TFE instance"
}

output "token" {
  value       = nonsensitive(module.tfe_install.token)
  description = "The token for TFE instance"
  sensitive   = false
}
