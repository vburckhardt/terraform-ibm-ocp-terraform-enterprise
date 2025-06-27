########################################################################################################################
# Resource Group
########################################################################################################################

module "resource_group" {
  source  = "terraform-ibm-modules/resource-group/ibm"
  version = "1.2.0"
  # if an existing resource group is not set (null) create a new one using prefix
  resource_group_name          = var.resource_group == null ? "${var.prefix}-resource-group" : null
  existing_resource_group_name = var.resource_group
}

##############################################################################
# Create Cloud Object Storage instance and a bucket
##############################################################################

module "cos" {
  source                 = "terraform-ibm-modules/cos/ibm"
  version                = "9.0.8"
  resource_group_id      = module.resource_group.resource_group_id
  region                 = var.region
  cos_instance_name      = "${var.prefix}-tfe"
  cos_tags               = var.resource_tags
  bucket_name            = "${var.prefix}-tfe-bucket"
  create_cos_bucket      = true
  retention_enabled      = false # disable retention for test environments - enable for stage/prod
  kms_encryption_enabled = false
  resource_keys = [
    {
      name                      = "tfe-credentials"
      generate_hmac_credentials = true
      role                      = "Writer"
    }
  ]
}


########################################################################################################################
# VPC
########################################################################################################################

module "ocp_vpc" {
  source            = "./modules/ocp-vpc"
  region            = var.region
  prefix            = var.prefix
  resource_group_id = module.resource_group.resource_group_id
}


# Download cluster config which is required to connect to cluster
data "ibm_container_cluster_config" "cluster_config" {
  cluster_name_id   = module.ocp_vpc.cluster_id
  resource_group_id = module.resource_group.resource_group_id
  config_dir        = "${path.module}/kubeconfig"
}


########################################################################################################################
# ICD Postgres
########################################################################################################################

module "icd_postgres" {
  source             = "terraform-ibm-modules/icd-postgresql/ibm"
  version            = "3.22.25"
  resource_group_id  = module.resource_group.resource_group_id
  name               = "${var.prefix}-data-store"
  pg_version         = "16" # TFE supports up to Postgres 16 (not 17)
  region             = var.region
  service_endpoints  = "public-and-private"
  member_host_flavor = "multitenant"
  service_credential_names = {
    "tfe" : "Operator"
  }
}

########################################################################################################################
# Redis
########################################################################################################################

module "redis" {
  source = "./modules/redis"
}

### TFE
module "tfe_install" {
  source                    = "./modules/tfe-install"
  cluster_id                = module.ocp_vpc.cluster_id
  cluster_resource_group_id = module.resource_group.resource_group_id
  namespace                 = "tfe-dev"
  tfe_license               = var.tfe_license
  tfe_database_host         = "${module.icd_postgres.hostname}:${module.icd_postgres.port}"
  tfe_database_user         = module.icd_postgres.service_credentials_object.credentials["tfe"].username
  tfe_database_password     = module.icd_postgres.service_credentials_object.credentials["tfe"].password

  tfe_s3_bucket     = module.cos.bucket_name
  tfe_s3_region     = var.region
  tfe_s3_access_key = module.cos.resource_keys["tfe-credentials"].credentials["cos_hmac_keys.access_key_id"]
  tfe_s3_secret_key = module.cos.resource_keys["tfe-credentials"].credentials["cos_hmac_keys.secret_access_key"]
  tfe_s3_endpoint   = module.cos.s3_endpoint_public

  tfe_redis_host     = module.redis.redis_host
  tfe_redis_password = module.redis.password_base64

  admin_username = var.admin_username
  admin_password = var.admin_password
  admin_email    = var.admin_email
}

resource "tfe_organization" "tfe_org" {
  name  = "ibm_cloud"
  email = var.admin_email
}
