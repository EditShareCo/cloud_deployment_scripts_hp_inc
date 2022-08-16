/*
 * © Copyright 2022 HP Development Company, L.P.
 *
 * This source code is licensed under the MIT license found in the
 * LICENSE file in the root directory of this source tree.
 */

locals {
  prefix = var.prefix != "" ? "${var.prefix}-" : ""

  provisioning_script = "awc-provisioning.sh"
  cas_mgr_script      = "get-connector-token.py"

  instance_info_list = flatten(
    [ for i in range(length(var.zone_list)):
      [ for j in range(var.instance_count_list[i]):
        {
          zone   = var.zone_list[i],
          subnet = var.subnet_list[i],
        }
      ]
    ]
  )
  tls_key_filename  = var.tls_key  == "" ? "" : basename(var.tls_key)
  tls_cert_filename = var.tls_cert == "" ? "" : basename(var.tls_cert)
}

resource "aws_s3_object" "get-connector-token-script" {
  count = length(local.instance_info_list) == 0 ? 0 : 1

  bucket = var.bucket_name
  key    = local.cas_mgr_script
  source = "${path.module}/${local.cas_mgr_script}"
}

resource "aws_s3_object" "tls-key" {
  count = length(local.instance_info_list) == 0 ? 0 : var.tls_key == "" ? 0 : 1

  bucket = var.bucket_name
  key    = local.tls_key_filename
  source = var.tls_key
}

resource "aws_s3_object" "tls-cert" {
  count = length(local.instance_info_list) == 0 ? 0 : var.tls_cert == "" ? 0 : 1

  bucket = var.bucket_name
  key    = local.tls_cert_filename
  source = var.tls_cert
}

resource "aws_s3_object" "awc-provisioning-script" {
  count = length(local.instance_info_list) == 0 ? 0 : 1

  key     = local.provisioning_script
  bucket  = var.bucket_name
  content = templatefile(
    "${path.module}/${local.provisioning_script}.tmpl",
    {
      ad_service_account_password       = var.ad_service_account_password,
      ad_service_account_username       = var.ad_service_account_username,
      awc_extra_install_flags           = var.awc_extra_install_flags,
      aws_region                        = var.aws_region,
      aws_ssm_enable                    = var.aws_ssm_enable,
      bucket_name                       = var.bucket_name,
      cas_mgr_deployment_sa_file        = var.cas_mgr_deployment_sa_file,
      cas_mgr_insecure                  = var.cas_mgr_insecure ? "true" : "",
      cas_mgr_script                    = local.cas_mgr_script,
      cas_mgr_url                       = var.cas_mgr_url,
      cloudwatch_enable                 = var.cloudwatch_enable,
      cloudwatch_setup_script           = var.cloudwatch_setup_script,
      computers_dn                      = var.computers_dn,
      customer_master_key_id            = var.customer_master_key_id,
      domain_controller_ip              = var.domain_controller_ip,
      domain_name                       = var.domain_name,
      ldaps_cert_filename               = var.ldaps_cert_filename,
      lls_ip                            = var.lls_ip,
      tls_cert                          = local.tls_cert_filename,
      tls_key                           = local.tls_key_filename,
      teradici_download_token           = var.teradici_download_token,
      users_dn                          = var.users_dn,
    }
  )
}

data "template_file" "user-data" {
  template = file("${path.module}/user-data.sh.tmpl")

  vars = {
    bucket_name         = var.bucket_name,
    provisioning_script = local.provisioning_script,
  }
}

# Need to do this to look up AMI ID, which is different for each region
data "aws_ami" "ami" {
  most_recent = true
  owners      = [var.ami_owner]

  filter {
    name   = "name"
    values = [var.ami_name]
  }
}

data "aws_iam_policy_document" "instance-assume-role-policy-doc" {
  statement {
    actions = [ "sts:AssumeRole" ]

    principals {
      type        = "Service"
      identifiers = ["ec2.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "awc-role" {
  count = length(local.instance_info_list) == 0 ? 0 : 1

  name               = "${local.prefix}awc_role"
  assume_role_policy = data.aws_iam_policy_document.instance-assume-role-policy-doc.json
}

data "aws_kms_key" "encryption-key" {
  count = var.customer_master_key_id == "" ? 0 : 1

  key_id = var.customer_master_key_id
}

data "aws_iam_policy_document" "awc-policy-doc" {
  statement {
    actions   = ["ec2:DescribeTags"]
    resources = ["*"]
    effect    = "Allow"
  }
  
  statement {
    actions   = ["s3:GetObject"]
    resources = [
      "arn:aws:s3:::${var.bucket_name}/${local.provisioning_script}",
      "arn:aws:s3:::${var.bucket_name}/${local.cas_mgr_script}",
      "arn:aws:s3:::${var.bucket_name}/${var.cas_mgr_deployment_sa_file}",
      "arn:aws:s3:::${var.bucket_name}/${var.cloudwatch_setup_script}",
      "arn:aws:s3:::${var.bucket_name}/${var.ldaps_cert_filename}",
    ]
    effect    = "Allow"
  }

  # add minimal permissions to allow users to connect to instances using Session Manager
  statement {
    actions   = ["ssm:UpdateInstanceInformation",
                "ssmmessages:CreateControlChannel",
                "ssmmessages:CreateDataChannel",
                "ssmmessages:OpenControlChannel",
                "ssmmessages:OpenDataChannel"]
    resources = ["*"]
    effect    = "Allow"
  }

  dynamic statement {
    for_each = aws_s3_object.tls-key
    iterator = i
    content {
      actions   = ["s3:GetObject"]
      resources = ["arn:aws:s3:::${var.bucket_name}/${local.tls_key_filename}"]
      effect    = "Allow"
    }
  }

  dynamic statement {
    for_each = aws_s3_object.tls-cert
    iterator = i
    content {
      actions   = ["s3:GetObject"]
      resources = ["arn:aws:s3:::${var.bucket_name}/${local.tls_cert_filename}"]
      effect    = "Allow"
    }
  }

  statement {
    actions   = [
      "logs:CreateLogGroup",
      "logs:CreateLogStream",
      "logs:DescribeLogStreams",
      "logs:PutLogEvents",
    ]
    resources = ["arn:aws:logs:*:*:*"]
    effect    = "Allow"
  }

  # add minimal permissions to allow users to connect to instances using Session Manager
  dynamic statement {
    for_each = var.aws_ssm_enable ? [1] : []
    content {
      actions   = ["ssm:UpdateInstanceInformation",
                  "ssmmessages:CreateControlChannel",
                  "ssmmessages:CreateDataChannel",
                  "ssmmessages:OpenControlChannel",
                  "ssmmessages:OpenDataChannel"]
      resources = ["*"]
      effect    = "Allow"
    }
  }

  dynamic statement {
    for_each = data.aws_kms_key.encryption-key
    iterator = i
    content {
      actions   = ["kms:Decrypt"]
      resources = [i.value.arn]
      effect    = "Allow"
    }
  }
}

resource "aws_iam_role_policy" "awc-role-policy" {
  count = length(local.instance_info_list) == 0 ? 0 : 1

  name = "${local.prefix}awc_role_policy"
  role = aws_iam_role.awc-role[0].id
  policy = data.aws_iam_policy_document.awc-policy-doc.json
}

resource "aws_iam_instance_profile" "awc-instance-profile" {
  count = length(local.instance_info_list) == 0 ? 0 : 1

  name = "${local.prefix}awc_instance_profile"
  role = aws_iam_role.awc-role[0].name
}

resource "aws_cloudwatch_log_group" "instance-log-group" {
  count = var.cloudwatch_enable ? length(local.instance_info_list) : 0

  name = "${local.prefix}${var.host_name}-${count.index}"
}

resource "time_sleep" "delay_destroy_log_group" {
  depends_on = [aws_cloudwatch_log_group.instance-log-group]

  destroy_duration = "5s"
}

resource "aws_instance" "awc" {
  count = length(local.instance_info_list)

  depends_on = [
    aws_s3_object.tls-key,
    aws_s3_object.tls-cert,
    aws_s3_object.get-connector-token-script,
    aws_s3_object.awc-provisioning-script,
    # wait 5 seconds before deleting the log group to account for delays in 
    # Cloudwatch receiving the last messages before an EC2 instance is shut down
    time_sleep.delay_destroy_log_group
  ]

  availability_zone = local.instance_info_list[count.index].zone
  subnet_id         = local.instance_info_list[count.index].subnet

  ami           = data.aws_ami.ami.id
  instance_type = var.instance_type

  root_block_device {
    volume_type = "gp2"
    volume_size = var.disk_size_gb
  }

  associate_public_ip_address = true

  vpc_security_group_ids = var.security_group_ids

  key_name = var.admin_ssh_key_name

  iam_instance_profile = aws_iam_instance_profile.awc-instance-profile[0].name

  user_data = data.template_file.user-data.rendered

  tags = {
    Name = "${local.prefix}${var.host_name}-${count.index}"
  }
}
