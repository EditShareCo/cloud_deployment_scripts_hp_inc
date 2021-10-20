# Copyright (c) 2019 Teradici Corporation
#
# This source code is licensed under the MIT license found in the
# LICENSE file in the root directory of this source tree.

#!/bin/bash

AD_SERVICE_ACCOUNT_PASSWORD=${ad_service_account_password}
AD_SERVICE_ACCOUNT_USERNAME=${ad_service_account_username}
AUTO_SHUTDOWN_IDLE_TIMER=${minutes_idle_before_shutdown}
CPU_POLLING_INTERVAL=${minutes_cpu_polling_interval}
DOMAIN_CONTROLLER_IP=${domain_controller_ip}
DOMAIN_NAME=${domain_name}
ENABLE_AUTO_SHUTDOWN=${enable_workstation_idle_shutdown}
KMS_CRYPTOKEY_ID=${kms_cryptokey_id}
PCOIP_REGISTRATION_CODE=${pcoip_registration_code}
TERADICI_DOWNLOAD_TOKEN=${teradici_download_token}


LOG_FILE="/var/log/teradici/provisioning.log"

METADATA_BASE_URI="http://metadata.google.internal/computeMetadata/v1/instance"
METADATA_AUTH_URI="$METADATA_BASE_URI/service-accounts/default/token"
DECRYPT_URI="https://cloudkms.googleapis.com/v1/$KMS_CRYPTOKEY_ID:decrypt"
TERADICI_REPO_SETUP_SCRIPT_URL="https://dl.teradici.com/$TERADICI_DOWNLOAD_TOKEN/pcoip-agent/cfg/setup/bash.rpm.sh"

log() {
    local message="$1"
    echo "[$(date)] $message"
}

retry() {
    local retries=0
    local max_retries=3
    until [[ $retries -ge $max_retries ]]
    do  
    # Break if command succeeds, or log then retry if command fails.
        $@ && break || {

            log "--> Failed to run command. $@"
            log "--> Retries left... $(( $max_retries - $retries ))"
            ((retries++))
            sleep 10;
        }
    done

    if [[ $retries -eq $max_retries ]]
    then
        return 1
    fi
}

get_credentials() {
    # Disable logging of secrets by wrapping the region with set +x and set -x
    set +x
    if [[ -z "$KMS_CRYPTOKEY_ID" ]]; then
        log "--> Script is not using encryption for secrets."

    else
        log "--> Script is using encryption key: $KMS_CRYPTOKEY_ID"

        # Gets access token attribute of response json object
        token=$(curl "$METADATA_AUTH_URI" -H "Metadata-Flavor: Google" | python -c "import sys, json; print json.load(sys.stdin)['access_token']")

        # Gets data using access token and decodes it
        log "--> Decrypting pcoip_registration_code..."
        data=$(echo "{ \"ciphertext\": \"$PCOIP_REGISTRATION_CODE\" }")
        b64_data=$(curl -X POST -d "$data" "$DECRYPT_URI" -H "Authorization: Bearer $token" -H "Content-type: application/json" | python -c "import sys, json; print json.load(sys.stdin)['plaintext']")
        PCOIP_REGISTRATION_CODE=$(echo "$b64_data" | base64 --decode)

        log "--> Decrypting ad_service_account_password..."
        data=$(echo "{ \"ciphertext\": \"$AD_SERVICE_ACCOUNT_PASSWORD\" }")
        b64_data=$(curl -X POST -d "$data" "$DECRYPT_URI" -H "Authorization: Bearer $token" -H "Content-type: application/json" | python -c "import sys, json; print json.load(sys.stdin)['plaintext']")
        AD_SERVICE_ACCOUNT_PASSWORD=$(echo "$b64_data" | base64 --decode)
    fi
    set -x
}

check_required_vars() {
    set +x
    if [[ -z "$PCOIP_REGISTRATION_CODE" ]]; then
        log "--> ERROR: Missing PCoIP Registration Code."
        missing_vars="true"
    fi

    if [[ -z "$AD_SERVICE_ACCOUNT_PASSWORD" ]]; then
        log "--> ERROR: Missing Active Directory Service Account Password."
        missing_vars="true"
    fi
    set -x

    if [[ "$missing_vars" = "true" ]]; then
        log "--> Exiting..."
        exit 1
    fi
}

exit_and_restart() {
    log "--> Rebooting..."
    (sleep 1; reboot -p) &
    exit
}

install_pcoip_agent() {
    log "--> Getting Teradici PCoIP agent repo..."
    curl --retry 3 --retry-delay 5 -u "token:$TERADICI_DOWNLOAD_TOKEN" -1sLf $TERADICI_REPO_SETUP_SCRIPT_URL | bash
    if [ $? -ne 0 ]; then
        log "--> ERROR: Failed to install PCoIP agent repo."
        exit 1
    fi
    log "--> PCoIP agent repo installed successfully."

    log "--> Installing USB dependencies..."
    retry "yum install -y usb-vhci"
    if [ $? -ne 0 ]; then
        log "--> Warning: Failed to install usb-vhci."
    fi
    log "--> usb-vhci successfully installed."

    log "--> Installing PCoIP standard agent..."
    retry yum -y install pcoip-agent-standard
    if [ $? -ne 0 ]; then
        log "--> ERROR: Failed to install PCoIP agent."
        exit 1
    fi
    log "--> PCoIP agent installed successfully."

    log "--> Registering PCoIP agent license..."
    n=0
    set +x
    while true; do
        /usr/sbin/pcoip-register-host --registration-code="$PCOIP_REGISTRATION_CODE" && break
        n=$[$n+1]

        if [ $n -ge 10 ]; then
            log "--> ERROR: Failed to register PCoIP agent after $n tries."
            exit 1
        fi

        log "--> ERROR: Failed to register PCoIP agent. Retrying in 10s..."
        sleep 10
    done
    set -x
    log "--> PCoIP agent registered successfully."
}

install_idle_shutdown() {
    log "--> Installing idle shutdown..."
    mkdir /tmp/idleShutdown

    retry wget "https://raw.githubusercontent.com/teradici/deploy/master/remote-workstations/new-agent-vm/Install-Idle-Shutdown.sh" -O /tmp/idleShutdown/Install-Idle-Shutdown-raw.sh

    awk '{ sub("\r$", ""); print }' /tmp/idleShutdown/Install-Idle-Shutdown-raw.sh > /tmp/idleShutdown/Install-Idle-Shutdown.sh && chmod +x /tmp/idleShutdown/Install-Idle-Shutdown.sh

    log "--> Setting auto shutdown idle timer to $AUTO_SHUTDOWN_IDLE_TIMER minutes..."
    INSTALL_OPTS="--idle-timer $AUTO_SHUTDOWN_IDLE_TIMER"
    if [[ "$ENABLE_AUTO_SHUTDOWN" = "false" ]]; then
        INSTALL_OPTS="$INSTALL_OPTS --disabled"
    fi

    retry /tmp/idleShutdown/Install-Idle-Shutdown.sh $INSTALL_OPTS

    exitCode=$?
    if [[ $exitCode -ne 0 ]]; then
        log "--> ERROR: Failed to install idle shutdown."
        exit 1
    fi

    if [[ $CPU_POLLING_INTERVAL -ne 15 ]]; then
        log "--> Setting CPU polling interval to $CPU_POLLING_INTERVAL minutes..."
        sed -i "s/OnUnitActiveSec=15min/OnUnitActiveSec=$${CPU_POLLING_INTERVAL}min/g" /etc/systemd/system/CAMIdleShutdown.timer.d/CAMIdleShutdown.conf
        systemctl daemon-reload
    fi
}

join_domain() {
    local dns_record_file="dns_record"
    if [[ ! -f "$dns_record_file" ]]
    then
        log "--> DOMAIN NAME: $DOMAIN_NAME"
        log "--> USERNAME: $AD_SERVICE_ACCOUNT_USERNAME"
        log "--> DOMAIN CONTROLLER: $DOMAIN_CONTROLLER_IP"

        VM_NAME=$(hostname)

        # Wait for AD service account to be set up
        yum -y install openldap-clients
        log "--> Waiting for AD account $AD_SERVICE_ACCOUNT_USERNAME@$DOMAIN_NAME to be available..."
        set +x
        until ldapwhoami -H ldap://$DOMAIN_CONTROLLER_IP -D $AD_SERVICE_ACCOUNT_USERNAME@$DOMAIN_NAME -w "$AD_SERVICE_ACCOUNT_PASSWORD" -o nettimeout=1 > /dev/null 2>&1
        do
            log "--> $AD_SERVICE_ACCOUNT_USERNAME@$DOMAIN_NAME not available yet, retrying in 10 seconds..."
            sleep 10
        done
        set -x

        # Join domain
        log "--> Installing required packages to join domain..."
        yum -y install sssd realmd oddjob oddjob-mkhomedir adcli samba-common samba-common-tools krb5-workstation openldap-clients policycoreutils-python

        log "--> Joining the domain '$DOMAIN_NAME'..."
        local retries=10

        set +x
        while true
        do
            echo "$AD_SERVICE_ACCOUNT_PASSWORD" | realm join --user="$AD_SERVICE_ACCOUNT_USERNAME@$DOMAIN_NAME" "$DOMAIN_NAME" --verbose >&2

            local rc=$?
            if [[ $rc -eq 0 ]]
            then
                log "--> Successfully joined domain '$DOMAIN_NAME'."
                break
            fi

            if [ $retries -eq 0 ]
            then
                log "--> ERROR: Failed to join domain '$DOMAIN_NAME'."
                return 106
            fi

            log "--> ERROR: Failed to join domain '$DOMAIN_NAME'. $retries retries remaining..."
            retries=$((retries-1))
            sleep 60
        done
        set -x

        domainname "$VM_NAME.$DOMAIN_NAME"
        echo "%$DOMAIN_NAME\\\\Domain\\ Admins ALL=(ALL) ALL" > /etc/sudoers.d/sudoers

        log "--> Registering with DNS..."
        DOMAIN_UPPER=$(echo "$DOMAIN_NAME" | tr '[:lower:]' '[:upper:]')
        IP_ADDRESS=$(hostname -I | grep -Eo '10.([0-9]*\.){2}[0-9]*')
        set +x
        echo "$AD_SERVICE_ACCOUNT_PASSWORD" | kinit "$AD_SERVICE_ACCOUNT_USERNAME"@"$DOMAIN_UPPER"
        set -x
        touch "$dns_record_file"
        echo "server $DOMAIN_CONTROLLER_IP" > "$dns_record_file"
        echo "update add $VM_NAME.$DOMAIN_NAME 600 a $IP_ADDRESS" >> "$dns_record_file"
        echo "send" >> "$dns_record_file"
        nsupdate -g "$dns_record_file"

        log "--> Configuring settings..."
        sed -i '$ a\dyndns_update = True\ndyndns_ttl = 3600\ndyndns_refresh_interval = 43200\ndyndns_update_ptr = True\nldap_user_principal = nosuchattribute' /etc/sssd/sssd.conf
        sed -c -i "s/\\(use_fully_qualified_names *= *\\).*/\\1False/" /etc/sssd/sssd.conf
        sed -c -i "s/\\(fallback_homedir *= *\\).*/\\1\\/home\\/%u/" /etc/sssd/sssd.conf

        # sssd.conf configuration is required first before enabling sssd
        log "--> Restarting messagebus service..."
        if ! (systemctl restart messagebus)
        then
            log "--> ERROR: Failed to restart messagebus service."
            return 106
        fi

        log "--> Enabling and starting sssd service..."
        if ! (systemctl enable sssd --now)
        then
            log "--> ERROR: Failed to start sssd service."
            return 106
        fi
    fi
}

if (rpm -q pcoip-agent-standard); then
    exit
fi

if [[ ! -f "$LOG_FILE" ]]
then
    mkdir -p "$(dirname $LOG_FILE)"
    touch "$LOG_FILE"
    chmod +644 "$LOG_FILE"
fi

log "$(date)"

# Print all executed commands to the terminal
set -x

# Redirect stdout and stderr to the log file
exec &>>$LOG_FILE

get_credentials

check_required_vars

yum -y update

yum install -y wget

# Install GNOME and set it as the desktop
log "--> Installing Linux GUI..."
yum -y groupinstall "GNOME Desktop" "Graphical Administration Tools"
# yum -y groupinstall "Server with GUI"

log "--> Setting default to graphical target..."
systemctl set-default graphical.target

join_domain

if ! (rpm -q pcoip-agent-standard)
then
    install_pcoip_agent
else
    log "--> pcoip-agent-standard is already installed."
fi

install_idle_shutdown

log "--> Installation is complete!"

exit_and_restart
