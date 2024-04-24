This is a fork of the cloud\_deployment\_scripts repo from HP\_Inc.  It has been named cloud\_deployment\_scripts\_hp\_inc to distinguish it from the initial fork we did from that repo, which was before Teradici was purchased by HP.

The contents of the repo are left mostly unchanged, especially for the Connector and Manager.  A summary of what has been changed and why is provided below

- removed all `version.tf` and `provider.tf` files: This is done because the original repo acts as a standalone terraform project, and as such it defines that information in multiple locations.  However we treat this as a submodule (think library), and as such all of those definitions conflict with the baselines we have established.  Shell scripts have been added to the root of the repo to assist in cleaning up all those files.
- awc
  - The provisioning script has been modified to install and configure `socat`, which we use to forward RDP sessions to the domain controller.  This is a useful extension since the domain controller only has a private IP in Cloud Edit+ deployments.
  - Addition of a lifecyle block to prevent the instance from being replaced if the AMI selected happens to change, and tags to the root\_block\_device.
  - Replacement of all usages of `template_file` data sources to use `templatefile()` to support Terraform versions `>=1.7` as provider has been deprecated [CP-6]
- awm
  - Addition of a lifecyle block to prevent the instance from being replaced if the AMI selected happens to change, and tags to the root\_block\_device.
  - Replacement of all usages of `template_file` data sources to use `templatefile()` to support Terraform versions `>=1.7` as provider has been deprecated [CP-6]

In addition to the above changes, there are some notes about the EditShare use of this repo:

- dc
  - There are a few changes here, that were significant enough that we made our own copy of the modules/aws/dc set of code and modified things there. Our version of the DC is maintained in the terraform-deploy repo.
  - Addition of a lifecycle block to prevent the instance from being replaced if the AMI selected happens to change.
- cas-mgr-single-connector
  - There are a number of changes to help ensure that the CAS components are deployed in accordance with the Cloud Edit+ architecture. Our version of the cas-mgr-single-connector is maintained in the terraform-deploy repo.
  - Ensuring that the domain controller is in a private subnet.
  - Remove anything to do with creating workstations, since those are managed by the terraform-deploy repo at a layer above this submodule.
