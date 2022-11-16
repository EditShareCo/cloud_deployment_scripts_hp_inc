/*
 * Copyright (c) 2019 Teradici Corporation
 *
 * This source code is licensed under the MIT license found in the
 * LICENSE file in the root directory of this source tree.
 */

locals {
  prefix = var.prefix != "" ? "${var.prefix}-" : ""

  awm_script = "get-cac-token.py"

  num_regions = length(var.gcp_region_list)
  num_cacs = length(flatten(
    [for i in range(local.num_regions) :
      range(var.instance_count_list[i])
    ]
  ))

  ssl_key_filename  = var.ssl_key == "" ? "" : basename(var.ssl_key)
  ssl_cert_filename = var.ssl_cert == "" ? "" : basename(var.ssl_cert)
}

resource "google_storage_bucket_object" "get-cac-token-script" {
  count = local.num_cacs == 0 ? 0 : 1

  bucket = var.bucket_name
  name   = local.awm_script
  source = "${path.module}/${local.awm_script}"
}

resource "google_storage_bucket_object" "ssl-key" {
  count = local.num_cacs == 0 ? 0 : var.ssl_key == "" ? 0 : 1

  bucket = var.bucket_name
  name   = local.ssl_key_filename
  source = var.ssl_key
}

resource "google_storage_bucket_object" "ssl-cert" {
  count = local.num_cacs == 0 ? 0 : var.ssl_cert == "" ? 0 : 1

  bucket = var.bucket_name
  name   = local.ssl_cert_filename
  source = var.ssl_cert
}

module "cac-regional" {
  source = "../../../modules/gcp/cac-regional"

  count = local.num_regions

  prefix = var.prefix

  gcp_region     = var.gcp_region_list[count.index]
  instance_count = var.instance_count_list[count.index]

  bucket_name            = var.bucket_name
  awm_deployment_sa_file = var.awm_deployment_sa_file

  awm_script                = local.awm_script
  cac_flag_manager_insecure = var.cac_flag_manager_insecure
  kms_cryptokey_id          = var.kms_cryptokey_id
  manager_url               = var.manager_url

  domain_controller_ip        = var.domain_controller_ip
  domain_name                 = var.domain_name
  ad_service_account_username = var.ad_service_account_username
  ad_service_account_password = var.ad_service_account_password

  ssl_key_filename  = local.ssl_key_filename
  ssl_cert_filename = local.ssl_cert_filename

  cac_extra_install_flags = var.cac_extra_install_flags

  network_tags           = var.network_tags
  subnet                 = var.subnet_list[count.index]
  external_pcoip_ip      = var.external_pcoip_ip_list == [] ? "" : var.external_pcoip_ip_list[count.index]
  enable_cac_external_ip = var.enable_cac_external_ip

  cac_admin_user             = var.cac_admin_user
  cac_admin_ssh_pub_key_file = var.cac_admin_ssh_pub_key_file
  cac_version                = var.cac_version
  teradici_download_token    = var.teradici_download_token

  gcp_service_account = var.gcp_service_account

  gcp_ops_agent_enable = var.gcp_ops_agent_enable
  ops_setup_script     = var.ops_setup_script

  depends_on = [
    google_storage_bucket_object.ssl-key,
    google_storage_bucket_object.ssl-cert,
    google_storage_bucket_object.get-cac-token-script,
  ]
}
