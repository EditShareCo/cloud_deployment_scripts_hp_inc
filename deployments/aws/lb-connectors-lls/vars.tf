/*
 * Copyright Teradici Corporation 2020-2022;  © Copyright 2022 HP Development Company, L.P.
 *
 * This source code is licensed under the MIT license found in the
 * LICENSE file in the root directory of this source tree.
 */

variable "aws_credentials_file" {
    description = "Location of AWS credentials file"
    type        = string

    validation {
      condition = fileexists(var.aws_credentials_file)
      error_message = "The aws_credentials_file specified does not exist. Please check the file path."
    }
}

variable "aws_region" {
  description = "AWS region"
  default     = "us-west-1"
}

# "usw2-az4" failed to provision t2.xlarge EC2 instances in April 2020
# "use1-az3" failed to provision g4dn.xlarge Windows EC2 instances in April 2020
variable "az_id_exclude_list" {
  description = "List of Availability Zone IDs to exclude."
  default     = ["usw2-az4", "use1-az3"]
}

# NetBIOS name is limited to 15 characters. 10 characters are reserved for workstation type
# and number of instance. e.g. -scent-999. So the max length for prefix is 5 characters. 
variable "prefix" {
  description = "Prefix to add to name of new resources. Must be <= 5 characters."
  default     = ""

  validation {
    condition     = length(var.prefix) <= 5
    error_message = "Prefix should have a maximum of 5 characters."
  }
}

variable "allowed_admin_cidrs" {
  description = "Open VPC firewall to allow ICMP, SSH, WinRM and RDP from these IP Addresses or CIDR ranges. e.g. ['a.b.c.d/32', 'e.f.g.0/24']"
  default     = []
}

variable "allowed_client_cidrs" {
  description = "Open VPC firewall to allow PCoIP connections from these IP Addresses or CIDR ranges. e.g. ['a.b.c.d/32', 'e.f.g.0/24']"
  default     = ["0.0.0.0/0"]
}

variable "vpc_name" {
  description = "Name for VPC containing the Cloud Access Software deployment"
  default     = "vpc-cas"
}

variable "vpc_cidr" {
  description = "CIDR for the VPC containing the CAS deployment"
  default     = "10.0.0.0/16" 
}

variable "dc_subnet_name" {
  description = "Name for subnet containing the Domain Controller"
  default     = "subnet-dc"
}

variable "dc_subnet_cidr" {
  description = "CIDR for subnet containing the Domain Controller"
  default     = "10.0.0.0/28"
}

variable "dc_instance_type" {
  description = "Instance type for the Domain Controller"
  default     = "t2.xlarge"
}

variable "dc_disk_size_gb" {
  description = "Disk size (GB) of the Domain Controller"
  default     = "50"
}

variable "dc_ami_owner" {
  description = "Owner of AMI for the Domain Controller"
  default     = "amazon"
}

variable "dc_ami_name" {
  description = "Name of the Windows AMI to create workstation from"
  default     = "Windows_Server-2019-English-Full-Base-2022.07.13"
}

variable "dc_pcoip_agent_version" {
  description = "Version of PCoIP Agent to install for Domain Controller"
  default     = "latest"
}

variable "domain_name" {
  description = "Domain name for the new domain"
  default     = "example.com"

  /* validation notes:
      - the name is at least 2 levels and at most 3, as we have only tested up to 3 levels
  */
  validation {
    condition = (
      length(regexall("([.]local$)",var.domain_name)) == 0 &&
      length(var.domain_name) < 256 &&
      can(regex(
        "(^[A-Za-z0-9][A-Za-z0-9-]{0,13}[A-Za-z0-9][.])([A-Za-z0-9][A-Za-z0-9-]{0,61}[A-Za-z0-9][.]){0,1}([A-Za-z]{2,}$)", 
        var.domain_name))
    )
    error_message = "Domain name is invalid. Please try again."
  }
}

variable "dc_admin_password" {
  description = "Password for the Administrator of the Domain Controller"
  type        = string
  sensitive   = true
}

variable "safe_mode_admin_password" {
  description = "Safe Mode Admin Password (Directory Service Restore Mode - DSRM)"
  type        = string
  sensitive   = true
}

variable "ad_service_account_username" {
  description = "Active Directory Service account name to be created"
  default     = "cas_ad_admin"
}

variable "ad_service_account_password" {
  description = "Active Directory Service account password"
  type        = string
  sensitive   = true
}

variable "domain_users_list" {
  description = "Active Directory users to create, in CSV format"
  type        = string
  default     = ""

  validation {
    condition = var.domain_users_list == "" ? true : fileexists(var.domain_users_list)
    error_message = "The domain_users_list file specified does not exist. Please check the file path."
  }
}

variable "lls_subnet_name" {
  description = "Name for subnet containing the PCoIP License Servers"
  default     = "subnet-lls"
}

variable "lls_subnet_cidr" {
  description = "CIDR for subnet containing the PCoIP License Servers"
  default     = "10.0.0.32/28"
}

variable "lls_instance_count" {
  description = "Number of PCoIP License Servers"
  default     = 1
}

variable "lls_instance_type" {
  description = "Instance type for the PCoIP License Server"
  default     = "t2.medium"
}

variable "lls_disk_size_gb" {
  description = "Disk size (GB) of the PCoIP License Server"
  default     = "10"
}

variable "lls_ami_owner" {
  description = "Owner of AMI for the PCoIP License Server"
  default     = "792107900819"
}

variable "lls_ami_name" {
  description = "Name of the Rocky Linux AMI to run PCoIP License Server on"
  default     = "Rocky-8-ec2-8.6-20220515.0.x86_64"
}

variable "lls_admin_password" {
  description = "Administrative password for the Teradici License Server"
  default     = ""
  sensitive   = true
}

variable "lls_activation_code" {
  description = "Activation Code for PCoIP session licenses"
  default     = ""
  sensitive   = true
}

variable "lls_license_count" {
  description = "Number of PCoIP session licenses to activate"
  default     = 0
}

variable "cac_zone_list" {
  description = "Zones in which to deploy Connectors"
  type        = list(string)
}

variable "cac_subnet_name" {
  description = "Name for subnets containing the Cloud Access Connector"
  default     = "subnet-cac"
}

variable "cac_subnet_cidr_list" {
  description = "CIDRs for subnets containing the Cloud Access Connector"
  type        = list(string)
}

variable "cac_instance_count_list" {
  description = "Number of Cloud Access Connector instances to deploy in each region"
  type        = list(number)
}

variable "cac_instance_type" {
  description = "Instance type for the Cloud Access Connector"
  default     = "t2.xlarge"
}

variable "cac_disk_size_gb" {
  description = "Disk size (GB) of the Cloud Access Connector"
  default     = "50"
}

variable "cac_ami_owner" {
  description = "Owner of AMI for the Cloud Access Connector"
  default     = "099720109477"
}

variable "cac_ami_name" {
  description = "Name of the AMI to create Cloud Access Connector from"
  default = "ubuntu/images/hvm-ssd/ubuntu-bionic-18.04-amd64-server-20220711"
}

variable "cac_version" {
  description = "Version of the Cloud Access Connector to install"
  default     = "latest"
}

variable "admin_ssh_key_name" {
  description = "Name of Admin SSH Key"
  default     = "cas_admin"
}

variable "admin_ssh_pub_key_file" {
  description = "Admin SSH public key file"
  type        = string

  validation {
    condition = fileexists(var.admin_ssh_pub_key_file)
    error_message = "The admin_ssh_pub_key_file specified does not exist. Please check the file path."
  }
}

# Note the following limits for health check:
# interval_sec: min 5, max 300, default 30
# timeout_sec:  min 2, max 120, default 5
variable "cac_health_check" {
  description = "Health check configuration for Cloud Access Connector"
  default = {
    path         = "/pcoip-broker/xml"
    protocol     = "HTTPS"
    port         = 443
    interval_sec = 30
    timeout_sec  = 5
  }
}

variable "ssl_key" {
  description = "SSL private key for the Connector in PEM format"
  default     = ""

  validation {
    condition = var.ssl_key == "" ? true : fileexists(var.ssl_key)
    error_message = "The ssl_key file specified does not exist. Please check the file path."
  }
}

variable "ssl_cert" {
  description = "SSL certificate for the Connector in PEM format"
  default     = ""

  validation {
    condition = var.ssl_cert == "" ? true : fileexists(var.ssl_cert)
    error_message = "The ssl_cert file specified does not exist. Please check the file path."
  }
}

variable "cac_extra_install_flags" {
  description = "Additional flags for installing CAC"
  default     = ""
}

variable "cas_mgr_url" {
  description = "CAS Manager as a Service URL"
  default     = "https://cas.teradici.com"
}

variable "cas_mgr_insecure" {
  description = "Allow unverified SSL access to CAS Manager"
  type        = bool
  default     = false
}

variable "cas_mgr_deployment_sa_file" {
  description = "Location of CAS Manager Deployment Service Account JSON file"
  type        = string

  validation {
    condition = fileexists(var.cas_mgr_deployment_sa_file)
    error_message = "The cas_mgr_deployment_sa_file specified does not exist. Please check the file path."
  }
}

variable "teradici_download_token" {
  description = "Token used to download from Teradici"
  default     = "yj39yHtgj68Uv2Qf"
}

variable "ws_subnet_name" {
  description = "Name for subnet containing Remote Workstations"
  default     = "subnet-ws"
}

variable "ws_subnet_cidr" {
  description = "CIDR for subnet containing Remote Workstations"
  default     = "10.0.2.0/24"
}

variable "enable_workstation_public_ip" {
  description = "Enable public IP for Workstations"
  default     = false
}

variable "win_gfx_instance_count" {
  description = "Number of Windows Graphics Workstations"
  default     = 0
}

variable "win_gfx_instance_name" {
  description = "Name for Windows Graphics Workstations"
  default     = "gwin"
}

# G4s are Tesla T4s
# G3s are M60
variable "win_gfx_instance_type" {
  description = "Instance type for the Windows Graphics Workstations"
  default     = "g4dn.xlarge"
}

variable "win_gfx_disk_size_gb" {
  description = "Disk size (GB) of the Windows Graphics Workstations"
  default     = "50"
}

variable "win_gfx_ami_owner" {
  description = "Owner of AMI for the Windows Graphics Workstations"
  default     = "amazon"
}

variable "win_gfx_ami_name" {
  description = "Name of the Windows AMI to create workstation from"
  default     = "Windows_Server-2019-English-Full-Base-2022.07.13"
}

variable "win_gfx_pcoip_agent_version" {
  description = "Version of PCoIP Agent to install for Windows Graphics Workstations"
  default     = "latest"
}

variable "win_std_instance_count" {
  description = "Number of Windows Standard Workstations"
  default     = 0
}

variable "win_std_instance_name" {
  description = "Name for Windows Standard Workstations"
  default     = "swin"
}

variable "win_std_instance_type" {
  description = "Instance type for the Windows Standard Workstations"
  default     = "t2.xlarge"
}

variable "win_std_disk_size_gb" {
  description = "Disk size (GB) of the Windows Standard Workstations"
  default     = "50"
}

variable "win_std_ami_owner" {
  description = "Owner of AMI for the Windows Standard Workstations"
  default     = "amazon"
}

variable "win_std_ami_name" {
  description = "Name of the Windows AMI to create workstation from"
  default     = "Windows_Server-2019-English-Full-Base-2022.07.13"
}

variable "win_std_pcoip_agent_version" {
  description = "Version of PCoIP Agent to install for Windows Standard Workstations"
  default     = "latest"
}

variable "centos_gfx_instance_count" {
  description = "Number of CentOS Graphics Workstations"
  default     = 0
}

variable "centos_gfx_instance_name" {
  description = "Name for CentOS Graphics Workstations"
  default     = "gcent"
}

# G4s are Tesla T4s
# G3s are M60
variable "centos_gfx_instance_type" {
  description = "Instance type for the CentOS Graphics Workstations"
  default     = "g4dn.xlarge"
}

variable "centos_gfx_disk_size_gb" {
  description = "Disk size (GB) of the CentOS Graphics Workstations"
  default     = "50"
}

variable "centos_gfx_ami_owner" {
  description = "Owner of AMI for the CentOS Graphics Workstations"
  default     = "125523088429"
}

variable "centos_gfx_ami_name" {
  description = "Name of the CentOS AMI to create workstation from"
  default     = "CentOS 7.9.2009 x86_64"
}

variable "centos_std_instance_count" {
  description = "Number of CentOS Standard Workstations"
  default     = 0
}

variable "centos_std_instance_name" {
  description = "Name for CentOS Standard Workstations"
  default     = "scent"
}

variable "centos_std_instance_type" {
  description = "Instance type for the CentOS Standard Workstations"
  default     = "t2.xlarge"
}

variable "centos_std_disk_size_gb" {
  description = "Disk size (GB) of the CentOS Standard Workstations"
  default     = "50"
}

variable "centos_std_ami_owner" {
  description = "Owner of AMI for the CentOS Standard Workstations"
  default     = "125523088429"
}

variable "centos_std_ami_name" {
  description = "Name of the CentOS AMI to create workstation from"
  default     = "CentOS 7.9.2009 x86_64"
}

variable "customer_master_key_id" {
  description = "The ID of the AWS KMS Customer Master Key used to decrypt secrets"
  default     = ""
}

variable "auto_logoff_enable" {
  description = "Enable auto log-off for Workstations"
  default     = true
}

variable "auto_logoff_minutes_idle_before_logoff" {
  description = "Minimum idle time for Workstations before auto log-off, must be between 5 and 10000"
  default     = 20
}

variable "auto_logoff_polling_interval_minutes" {
  description = "Polling interval for checking CPU utilization to determine if machine is idle, must be between 1 and 100"
  default     = 5
}

variable "auto_logoff_cpu_utilization" {
  description = "CPU utilization percentage, must be between 1 and 100"
  default     = 20
}

variable "idle_shutdown_enable" {
  description = "Enable auto idle shutdown for Workstations"
  default     = true
}

variable "idle_shutdown_minutes_idle_before_shutdown" {
  description = "Minimum idle time for Workstations before auto idle shutdown, must be between 5 and 10000"
  default     = 240
}

variable "idle_shutdown_polling_interval_minutes" {
  description = "Polling interval for checking CPU utilization to determine if machine is idle, must be between 1 and 60"
  default     = 15
}

variable "idle_shutdown_cpu_utilization" {
  description = "CPU utilization percentage, must be between 1 and 100"
  default     = 20
}

variable "cloudwatch_enable" {
  description = "Enable AWS CloudWatch Agent for sending logs to AWS CloudWatch"
  default     = true
}

variable "aws_ssm_enable" {
  description = "Enable AWS Session Manager integration for easier SSH/RDP admin access to EC2 instances"
  default     = true
}
