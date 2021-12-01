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

# # sem_version() converts a semver string so it can be compared in a test statement
# function sem_version { echo "$@" | awk -F. '{ printf("%d%03d%03d%03d\n", $1,$2,$3,$4); }'; }
#
# # Get the current csi version
# csi_version=$(csi version | awk '/App\. Version/ {print $4}')
#
# # v1.5.32 is when the new NTP metadata was installed, so check it is older than that
# if [ "$(sem_version $csi_version)" -le "$(sem_version "1.6.32")" ]; then
#     echo "Update csi to at least v1.5.32"
#     exit 2
# fi

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
  
  csi handoff bss-update-param --limit ${UPGRADE_XNAME} \
    --set ip=mgmt0:dhcp \

  echo "existing params"
  echo "$existing_params"
  echo "new params"
  cray bss bootparameters list --hosts ${UPGRADE_XNAME} --format json | jq '.[] |.params' | tr ' ' '\n'
}

# upgrade_ipam_metadata() will query a data.json to pull out the new key/value pairs
upgrade_ipam_metadata() {
  local query
  local payload
  local upgrade_file
  # jq -r '.["b8:59:9f:fe:49:f1"]'
  for k in $(jq -r 'to_entries[] | "\(.key)"' data.json)
  do
    # if it is not the global key, it is one of the host records we need to manipulate
    if ! [[ "$k" == "Global" ]]; then
      # shellcheck disable=SC2089
      query=".[\"$k\"][\"meta-data\"][\"ipam\"]"
      # shellcheck disable=SC2090
      payload="$(jq $query data.json)"

      # save the payload to a unique file
      upgrade_file="upgrade-ipam-${UPGRADE_XNAME}.json"
      cat <<EOF>"$upgrade_file"
{
  "meta-data": {
    "ipam": $payload
  }
}
EOF
      # handoff the new payload to bss
      csi handoff bss-update-cloud-init --user-data="$upgrade_file" --limit=${UPGRADE_XNAME}
    fi
  done
}

# patch_in_new_metadata() will mount PITDATA and run 'csi config init' in order to grab the newly-generated data.json and then push it into bss
patch_in_new_metadata() {
  # Try to find the files that we need, mounting the PITDATA partition if necessary and if possible
  # Create the mount point if it does not already exist (-p ensures this command passes regardless)
  mkdir -p /mnt/pitdata
  prep_dir=/mnt/pitdata/prep
  # These are the files that we need
  ncn_metadata="$prep_dir"/ncn_metadata.csv
  switch_metadata="$prep_dir"/switch_metadata.csv
  hmn_connections="$prep_dir"/hmn_connections.json
  system_config="$prep_dir"/system_config.yaml
  local pitdev
  if ! pitdev=$(blkid --label PITDATA); then
    if [[ -f "$ncn_metadata" ]] \
      && [[ -f "$switch_metadata" ]] \
      && [[ -f "$hmn_connections" ]] \
      && [[ -f "$system_config" ]]; then
        echo "PITDATA not found but seed files are present. Using those to generate new metadata..."
    else
      echo "PITDATA not found. Seed files are needed to generate new cloud-init metadata."
      echo "Re-create/re-populate the PITDATA partition"
      echo "or"
      echo "Copy seed files to /mnt/pitdata/prep"
      exit 1
    fi
  # Check to see if it is already mounted over this device
  elif [[ $(df --output="target,source" $pitdev 2>/dev/null | tail -1 | awk '{ print $1 }') == /mnt/pitdata ]]; then
    echo "PITDATA is already mounted"
    # We unset this to remember that we do not need to unmount it
    pitdev=""
  # There is a device with the PITDATA label but it is not mounted over /mnt/pitdata
  else
    echo "Mounting PITDATA..."
    mount -L PITDATA /mnt/pitdata/
  fi
  # we need the three seed files and the system_config to generate the metadata
  # this also ensures we are in the right place to run config init without any arguments
  if [[ -f "$ncn_metadata" ]] \
  && [[ -f "$switch_metadata" ]] \
  && [[ -f "$hmn_connections" ]] \
  && [[ -f "$system_config" ]]; then
    # find the system name
    system_name=$(awk '/system-name/ {print $2}' "$system_config")
    if [[ -d "$prep_dir/$system_name-1.0" ]]; then
      pushd "$prep_dir" || exit 1
        echo "Getting new metadata from existing..."
        # handoff the new data to bss
        pushd "$system_name/basecamp" || exit 1
          upgrade_ipam_metadata
        popd || exit 1
      popd || exit 1
    else
      pushd "$prep_dir" || exit 1
        # move the original generated configs out of the way
        mv "$system_name" "$system_name-1.0"
        echo "Generating new config payload for $system_name with csi..."
        # Run config init to get the new metadata
        csi config init
        echo "Getting new metadata..."
        # handoff the new data to bss
        pushd "$system_name/basecamp" || exit 1
          upgrade_ipam_metadata
        popd || exit 1
      popd || exit 1
    fi
  else
    echo "Missing seed file or system_config.yaml"
    echo "Seed files are needed to generate new cloud-init metadata."
    echo "Re-create/re-populate the PITDATA partition"
    echo "or"
    echo "Copy seed files to /mnt/pitdata/prep"
    exit 1
  fi

  # Unmount pitdata, if we mounted it.
  if [[ -n $pitdev ]]; then
    umount -l /mnt/pitdata/ || true
  fi
}

function update_write_files_user_data() {
    # Collect network information from SLS
    nmn_hmn_networks=$(curl -k -H "Authorization: Bearer ${TOKEN}" ${URL} 2>/dev/null | jq ".[] | {NetworkName: .Name, Subnets: .ExtraProperties.Subnets[]} | { NetworkName: .NetworkName, SubnetName: .Subnets.Name, SubnetCIDR: .Subnets.CIDR, Gateway: .Subnets.Gateway} | select(.SubnetName==\"network_hardware\") ")
    [[ -n ${nmn_hmn_networks} ]] || on_error "Cannot retrieve HMN and NMN networks from SLS. Check SLS connectivity."
    cabinet_networks=$(curl -k -H "Authorization: Bearer ${TOKEN}" ${URL} 2>/dev/null | jq ".[] | {NetworkName: .Name, Subnets: .ExtraProperties.Subnets[]} | { NetworkName: .NetworkName, SubnetName: .Subnets.Name, SubnetCIDR: .Subnets.CIDR} | select(.SubnetName | startswith(\"cabinet_\")) ")
    [[ -n ${cabinet_networks} ]] || on_error "Cannot retrieve cabinet networks from SLS. Check SLS connectivity."

    # NMN
    nmnlb=$(curl -k -H "Authorization: Bearer ${TOKEN}" ${URL} 2>/dev/null | jq ".[] | {NetworkName: .Name, Subnets: .ExtraProperties.Subnets[]} | { NetworkName: .NetworkName, SubnetCIDR: .Subnets.CIDR} | select(.NetworkName==\"NMNLB\")")
    nmnlb_cidr=$(echo $nmnlb | jq -r .SubnetCIDR)
    [[ -n ${nmnlb_cidr} ]] || on_error "NMN LB CIDR not found"
    nmn_gateway=$(echo "${nmn_hmn_networks}" | jq -r ". | select(.NetworkName==\"NMN\") | .Gateway")
    [[ -n ${nmn_gateway} ]] || on_error "NMN gateway not found"
    nmn_cabinet_subnets=$(echo "${cabinet_networks}" | jq -r ". | select(.NetworkName==\"NMN\" or .NetworkName==\"NMN_RVR\" or .NetworkName==\"NMN_MTN\") | .SubnetCIDR")
    [[ -n ${nmn_cabinet_subnets} ]] || on_error "NMN cabinet subnets not found"

    # HMN
    hmnlb=$(curl -k -H "Authorization: Bearer ${TOKEN}" ${URL} 2>/dev/null | jq ".[] | {NetworkName: .Name, Subnets: .ExtraProperties.Subnets[]} | { NetworkName: .NetworkName, SubnetCIDR: .Subnets.CIDR} | select(.NetworkName==\"HMNLB\")")
    hmnlb_cidr=$(echo $hmnlb | jq -r .SubnetCIDR)
    [[ -n ${hmnlb_cidr} ]] || on_error "HMN LB CIDR not found"
    hmn_gateway=$(echo "${nmn_hmn_networks}" | jq -r ". | select(.NetworkName==\"HMN\") | .Gateway")
    [[ -n ${hmn_gateway} ]] || on_error "HMN gateway not found"
    hmn_cabinet_subnets=$(echo "${cabinet_networks}" | jq -r ". | select(.NetworkName==\"HMN\" or .NetworkName==\"HMN_RVR\" or .NetworkName==\"HMN_MTN\") | .SubnetCIDR")
    [[ -n ${hmn_cabinet_subnets} ]] || on_error "HMN cabinet subnets not found"

    # MTL
    mtl_cidr=$(echo "${nmn_hmn_networks}" | jq -r ". | select(.NetworkName==\"MTL\") | .SubnetCIDR")
    [[ -n ${mtl_cidr} ]] || on_error "MTL CIDR not found"
    mtl_gateway=$(echo "${nmn_hmn_networks}" | jq -r ". | select(.NetworkName==\"MTL\") | .Gateway")
    [[ -n ${mtl_gateway} ]] || on_error "MTL gateway not found"

    # Format for ifroute-<interface> syntax
    nmn_routes=()
    for rt in $nmn_cabinet_subnets; do
        nmn_routes+=("$rt $nmn_gateway - bond0.nmn0")
    done
    nmn_routes+=("$nmnlb_cidr $nmn_gateway - bond0.nmn0")
    nmn_routes+=("$mtl_cidr $mtl_gateway - bond0.nmn0")

    hmn_routes=()
    for rt in $hmn_cabinet_subnets; do
        hmn_routes+=("$rt $hmn_gateway - bond0.hmn0")
    done
    hmn_routes+=("$hmnlb_cidr $hmn_gateway - bond0.hmn0")

    printf -v nmn_routes_string '%s\\n' "${nmn_routes[@]}"
    printf -v hmn_routes_string '%s\\n' "${hmn_routes[@]}"
    # generate json file for input to csi
cat <<EOF>write-files-user-data.json
{
  "user-data": {
    "write_files": [{
        "content": "${nmn_routes_string%,}",
        "owner": "root:root",
        "path": "/etc/sysconfig/network/ifroute-bond0.nmn0",
        "permissions": "0644"
      },
      {
        "content": "${hmn_routes_string%,}",
        "owner": "root:root",
        "path": "/etc/sysconfig/network/ifroute-bond0.hmn0",
        "permissions": "0644"
      }
    ]
  }
}
EOF
    # update bss
    csi handoff bss-update-cloud-init --user-data=write-files-user-data.json --limit=${UPGRADE_XNAME}
}

function update_k8s_runcmd_user_data() {
cat <<EOF>k8s-runcmd-user-data.json
{
  "user-data": {
    "runcmd": [
      "/srv/cray/scripts/metal/net-init.sh",
      "/srv/cray/scripts/common/update_ca_certs.py",
      "/srv/cray/scripts/metal/install.sh",
      "/srv/cray/scripts/common/kubernetes-cloudinit.sh",
      "/srv/cray/scripts/join-spire-on-storage.sh",
      "touch /etc/cloud/cloud-init.disabled"
    ]
  }
}
EOF
    # update bss
    csi handoff bss-update-cloud-init --user-data=k8s-runcmd-user-data.json --limit=${UPGRADE_XNAME}
}

function update_first_ceph_runcmd_user_data() {
cat <<EOF>first-ceph-runcmd-user-data.json
{
  "user-data": {
    "runcmd": [
      "/srv/cray/scripts/metal/net-init.sh",
      "/srv/cray/scripts/common/update_ca_certs.py",
      "/srv/cray/scripts/metal/install.sh",
      "/srv/cray/scripts/common/pre-load-images.sh",
      "touch /etc/cloud/cloud-init.disabled",
      "/srv/cray/scripts/common/ceph-enable-services.sh"
    ]
  }
}
EOF
    # update bss
    csi handoff bss-update-cloud-init --user-data=first-ceph-runcmd-user-data.json --limit=${UPGRADE_XNAME}
}

function update_ceph_worker_runcmd_user_data() {
cat <<EOF>ceph-worker-runcmd-user-data.json
{
  "user-data": {
    "runcmd": [
      "/srv/cray/scripts/metal/net-init.sh",
      "/srv/cray/scripts/common/update_ca_certs.py",
      "/srv/cray/scripts/metal/install.sh",
      "/srv/cray/scripts/common/pre-load-images.sh",
      "touch /etc/cloud/cloud-init.disabled",
      "/srv/cray/scripts/common/ceph-enable-services.sh"
    ]
  }
}
EOF
    # update bss
    csi handoff bss-update-cloud-init --user-data=ceph-worker-runcmd-user-data.json --limit=${UPGRADE_XNAME}
}

# same data on all NCNs
update_write_files_user_data
patch_in_new_metadata
update_interface_names

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
