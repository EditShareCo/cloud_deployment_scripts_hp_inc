/*
 * Copyright (c) 2019 Teradici Corporation
 *
 * This source code is licensed under the MIT license found in the
 * LICENSE file in the root directory of this source tree.
 */

variable "gcp_service_account" {
  description = "Service Account in the GCP Project"
  type        = string
}

variable "prefix" {
  description = "Prefix to add to name of new resources"
  default     = ""
}

variable "manager_url" {
  description = "Anyware Manager URL (e.g. https://cas.teradici.com)"
  type        = string
}

variable "cac_flag_manager_insecure" {
  description = "CAC install flag that allows unverified SSL access to Anyware Manager"
  type        = bool
  default     = false
}

variable "awm_deployment_sa_file" {
  description = "Location of Anyware Manager Deployment Service Account JSON file"
  type        = string
}

variable "domain_name" {
  description = "Name of the domain to join"
  type        = string

  /* validation notes:
      - the name is at least 2 levels and at most 3, as we have only tested up to 3 levels
  */
  validation {
    condition = (
      length(regexall("([.]local$)", var.domain_name)) == 0 &&
      length(var.domain_name) < 256 &&
      can(regex(
        "(^[A-Za-z0-9][A-Za-z0-9-]{0,13}[A-Za-z0-9][.])([A-Za-z0-9][A-Za-z0-9-]{0,61}[A-Za-z0-9][.]){0,1}([A-Za-z]{2,}$)",
      var.domain_name))
    )
    error_message = "Domain name is invalid. Please try again."
  }
}

variable "domain_controller_ip" {
  description = "Internal IP of the Domain Controller"
  type        = string
}

variable "ad_service_account_username" {
  description = "Active Directory Service Account username"
  type        = string
}

variable "ad_service_account_password" {
  description = "Active Directory Service Account password"
  type        = string
  sensitive   = true
}

variable "bucket_name" {
  description = "Name of bucket to retrieve provisioning script."
  type        = string
}

variable "gcp_region_list" {
  description = "GCP regions to set up the Managed Instance Groups"
  type        = list(string)
}

variable "subnet_list" {
  description = "Subnets to deploy the Cloud Access Connector"
  type        = list(string)
}

variable "network_tags" {
  description = "Tags to be applied to the Cloud Access Connector"
  type        = list(string)
}

variable "instance_count_list" {
  description = "Number of Cloud Access Connector instances to deploy in each region"
  type        = list(number)
}

variable "host_name" {
  description = "Name to give the host"
  default     = "vm-cac"
}

variable "machine_type" {
  description = "Machine type for the Cloud Access Connector (min 4 GB RAM, 2 vCPUs)"
  default     = "n1-standard-2"
}

variable "disk_size_gb" {
  description = "Disk size (GB) of the Cloud Access Connector (min 12 GB)"
  default     = "50"
}

variable "disk_image" {
  description = "Disk image for the Cloud Access Connector"
  default     = "projects/ubuntu-os-cloud/global/images/family/ubuntu-1804-lts"
}

variable "cac_admin_user" {
  description = "Username of the Cloud Access Connector Administrator"
  type        = string
}

variable "cac_admin_ssh_pub_key_file" {
  description = "SSH public key for the Cloud Access Connector Administrator"
  type        = string

  validation {
    condition     = fileexists(var.cac_admin_ssh_pub_key_file)
    error_message = "The cac_admin_ssh_pub_key_file specified does not exist. Please check the file path."
  }
}

variable "cac_extra_install_flags" {
  description = "Additional flags for installing CAC"
  default     = ""
}

variable "cac_version" {
  description = "Version of the Cloud Access Connector to install"
  default     = "latest"
}

variable "teradici_download_token" {
  description = "Token used to download from Teradici"
  default     = "yj39yHtgj68Uv2Qf"
}

variable "external_pcoip_ip" {
  description = "External IP addresses to use to connect to the Cloud Access Connectors."
  default     = ""
}

variable "kms_cryptokey_id" {
  description = "Resource ID of the KMS cryptographic key used to decrypt secrets, in the form of 'projects/<project-id>/locations/<location>/keyRings/<keyring-name>/cryptoKeys/<key-name>'"
  default     = ""
}

variable "ssl_key" {
  description = "SSL private key for the Connector"
  default     = ""
}

variable "ssl_cert" {
  description = "SSL certificate for the Connector"
  default     = ""
}

variable "ops_setup_script" {
  description = "The script that sets up the GCP Ops Agent"
  type        = string
}

variable "gcp_ops_agent_enable" {
  description = "Enable GCP Ops Agent for sending logs to GCP"
  default     = true
}
