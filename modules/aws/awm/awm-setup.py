#!/usr/bin/env python3

################################################
# Note this file has EditShare Customizations. #
################################################

# Copyright (c) 2020 Teradici Corporation;  © Copyright 2023 HP Development Company, L.P.
#
# This source code is licensed under the MIT license found in the
# LICENSE file in the root directory of this source tree.

import argparse
import json
import configparser
from typing import Any
import requests
import boto3
from botocore.exceptions import ClientError

AWM_API_URL = "https://localhost/api/v1"
ADMIN_USER = "adminUser"


def awm_login(user_name: str, password: str, req_sess: requests.Session) -> None:
    """Login to Anyware Manager API and set token to session."""
    payload = {
        "username": user_name,
        "password": password,
    }
    resp = req_sess.post(
        f"{AWM_API_URL}/auth/ad/login",
        json=payload,
    )
    resp.raise_for_status()

    token = resp.json()["data"]["token"]
    req_sess.headers.update({"Authorization": token})


def deployment_create(name: str, reg_code: str, req_sess: requests.Session) -> Any:
    """Create new Anyware Manager deployment."""
    payload = {
        "deploymentName": name,
        "registrationCode": reg_code,
    }
    resp = req_sess.post(
        f"{AWM_API_URL}/deployments",
        json=payload,
    )
    resp.raise_for_status()

    return resp.json()["data"]


def deployment_key_create(
    deployment_info: dict, name: str, req_sess: requests.Session  # type: ignore
) -> Any:
    """Create new Anyware Manager deployment key."""
    payload = {"deploymentId": deployment_info["deploymentId"], "keyName": name}
    resp = req_sess.post(
        f"{AWM_API_URL}/auth/keys",
        json=payload,
    )
    resp.raise_for_status()

    return resp.json()["data"]


def deployment_key_write(deployment_key: str, path: str) -> None:
    """Write Anyware Manager deployment key to file."""
    with open(path, "w", encoding="utf-8") as f:
        json.dump(deployment_key, f)


def get_aws_sa_key(path: str) -> configparser.SectionProxy:
    """Return AWS credentials from INI file"""
    config = configparser.ConfigParser()
    config.read(path)

    return config["default"]


def get_username(aws_key: configparser.SectionProxy) -> Any:
    """Get AWS username associated with the provided AWS credentials."""
    iam = boto3.resource("iam")
    try:
        resp = iam.meta.client.get_access_key_last_used(
            AccessKeyId=aws_key["aws_access_key_id"]
        )
        return resp["UserName"]
    except ClientError as e:
        # Not failing because AWS service account is optional
        print("Warning: error retrieving AWS username.")
        print(e)


def validate_aws_sa(
    user_name: str, aws_key: configparser.SectionProxy, req_sess: requests.Session
) -> bool:
    """Validate AWS credentials with Anyware Manager."""
    print("Validating AWS credentials with Anyware Manager...")
    payload = {
        "provider": "aws",
        "credential": {
            "userName": user_name,
            "accessKeyId": aws_key["aws_access_key_id"],
            "secretAccessKey": aws_key["aws_secret_access_key"],
        },
    }
    resp = req_sess.post(
        f"{AWM_API_URL}/auth/users/cloudServiceAccount/validate",
        json=payload,
    )
    try:
        resp.raise_for_status()
        return True
    except requests.exceptions.HTTPError as e:
        # Not failing because AWS service account is optional
        print("Warning: error validating AWS Service Account key.")
        print(e)

        if resp.status_code == 400:
            print(
                "Warning: error AWS Service Account key provided has insufficient permissions."
            )
            print(resp.json()["data"])

        return False


def deployment_add_aws_account(
    user_name: str,
    aws_key: configparser.SectionProxy,
    deployment_info: dict,  # type: ignore
    req_sess: requests.Session,
) -> None:
    """Add AWS credentials to Anyware Manager deployment."""
    credentials = {
        "userName": user_name,
        "accessKeyId": aws_key["aws_access_key_id"],
        "secretAccessKey": aws_key["aws_secret_access_key"],
    }
    payload = {
        "provider": "aws",
        "credential": credentials,
    }
    resp = req_sess.post(
        f"{AWM_API_URL}/deployments/{deployment_info['deploymentId']}/cloudServiceAccounts",
        json=payload,
    )

    try:
        resp.raise_for_status()
        print("Successfully added AWS cloud service account to deployment.")
    except requests.exceptions.HTTPError as e:
        # Not failing because AWS service account is optional
        print("Warning: error adding AWS Service Account to deployment.")
        print(e)


if __name__ == "__main__":
    parser = argparse.ArgumentParser(
        description="This script updates the password for the Anyware Manager Admin user."
    )

    parser.add_argument(
        "--deployment_name", required=True, help="Anyware Manager deployment to create"
    )
    parser.add_argument(
        "--key_file",
        required=True,
        help="path to write Deployment Service Account key JSON file",
    )
    parser.add_argument(
        "--key_name",
        required=True,
        help="name of Anyware Manager Deployment Service Account key",
    )
    parser.add_argument(
        "--password", required=True, help="new Anyware Manager administrator password"
    )
    parser.add_argument("--reg_code", required=True, help="PCoIP registration code")
    parser.add_argument("--aws_key", help="AWS Service Account credentials INI file")

    args = parser.parse_args()

    # Set up session to be used for all subsequent calls to Anyware Manager
    session = requests.Session()
    session.verify = False
    retry_strategy = requests.adapters.Retry(
        total=10,
        backoff_factor=1,
        status_forcelist=[500, 502, 503, 504],
        allowed_methods=["POST"],  # "method_whitelist" deprecated
    )
    session.mount("https://", requests.adapters.HTTPAdapter(max_retries=retry_strategy))

    # The credential for Anyware Manager login are stated in default configuration
    # https://www.teradici.com/web-help/anyware_manager/23.04/cam_standalone_installation/default_config/#5-access-the-admin-console
    print("Creating Anyware Manager deployment...")
    awm_login(ADMIN_USER, args.password, session)
    deployment = deployment_create(args.deployment_name, args.reg_code, session)
    awm_deployment_key = deployment_key_create(deployment, args.key_name, session)
    deployment_key_write(awm_deployment_key, args.key_file)

    if args.aws_key:
        key = get_aws_sa_key(args.aws_key)
        username = get_username(key)
        if username and validate_aws_sa(username, key, session):
            print("Adding AWS credentials to Anyware Manager deployment...")
            deployment_add_aws_account(username, key, deployment, session)
        else:
            print("Skip adding AWS credentials to Anyware Manager deployment.")
