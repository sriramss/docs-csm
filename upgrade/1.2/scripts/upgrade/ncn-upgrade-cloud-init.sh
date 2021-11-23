#!/usr/bin/env bash

# Copyright 2021 Hewlett Packard Enterprise Development LP

# shellcheck disable=SC2086

set -e

upgrade_ncn=$1

# shellcheck disable=SC1090,SC2086
. ${BASEDIR}/ncn-upgrade-common.sh $upgrade_ncn

URL="https://api-gw-service-nmn.local/apis/sls/v1/networks"

function on_error() {
    echo "Error: $1. Exiting"
    exit 1
}

if ! command -v csi &> /dev/null
then
    echo "csi could not be found in $PATH"
    exit 1
fi

# 1.2 uses new interface names, so we need to adjust the nodes boot parameters to match that of a fresh install
update_interface_names() {
  existing_params=""
  existing_params="$(cray bss bootparameters list --hosts ${UPGRADE_XNAME} --format json | jq '.[] |.params')"

  # delete these deprecated boot parameters
  csi handoff bss-update-param --limit ${UPGRADE_XNAME} \
    --delete bond \
    --delete bootdev \
    --delete hwprobe \
    --delete ip \
    --delete vlan

  # Add in a new ip parameter for DHCP
  csi handoff bss-update-param --limit ${UPGRADE_XNAME} \
    --set ip=mgmt0:dhcp \

  echo "existing params"
  echo "$existing_params"
  echo "new params"
  cray bss bootparameters list --hosts ${UPGRADE_XNAME} --format json | jq '.[] |.params' | tr ' ' '\n'
}

# upgrade_metadata() will use csi to query SLS and then generate the new metadata
upgrade_metadata() {
  # The logic to do all this handoff is within csi
  csi upgrade metadata --1-0-to-1-2
}

update_interface_names
upgrade_metadata

case ${upgrade_ncn} in
    ncn-s001)
        update_first_ceph_runcmd_user_data
        ;;
    ncn-s*)
        update_ceph_worker_runcmd_user_data
        ;;
    *)
        update_k8s_runcmd_user_data
        ;;
esac
