##############################################################################
# Outputs
##############################################################################

#output "myoutput" {
#  description = "Description of my output"
#  value       = "value"
#  depends_on  = [<some resource>]
#}

##############################################################################

output "tfe_installation_status" {
  description = "The status of the TFE installation"
  value       = helm_release.tfe_install.status
}

output "tfe_console_url" {
  description = "The URL to access the TFE console"
  value       = "https://${data.kubernetes_resource.tfe_route.object.status.ingress[0].host}"
}

output "tfe_hostname" {
  description = "The hostname for TFE instance"
  value       = data.kubernetes_resource.tfe_route.object.status.ingress[0].host
}
