# LiveCD Setup

This page will assist you with configuring the LiveCD, a.k.a. CRAY Pre-Install Toolkit.

## Requirements:

1. If you are installing a system that previously had 1.3 installed, move external network connections from ncn-w001 to ncn-m001
   - See [MOVE-SITE-CONNECTIONS](050-MOVE-SITE-CONNECTIONS.md).
2. A USB stick or other Block Device, local to ncn-m001.
   - The block device should be `>=256GB`
3. The drive letter of that device (i.e. `/dev/sdd`)
4. Access to stash/bitbucket
5. The CCD/SHCD `.xlsx` file for your system
6. The number of mountain and river cabinets in the system.
7. A set of configuration information sufficient to fill out the [listed flags for the `csi config init` command](#manual-step-6-configuation-payload)

To begin these LiveCD creation steps, you must be logged in to an operating system that is running on the disk of ncn-m001.  You should not be on the LiveCD running on the USB stick or other block device.

## Overview:

> NOTE: These steps will be automated. CASM/MTL is automating this process  with the cray-site-init tool.

1. [Setup ENV vars for use with `csi`](#manual-step-1-setup-csi)
2. [Download and expand the CSM release](#manual-step-2-download-and-expand-the-csm-release)
3. [Install `csi`](#manual-step-3-install-csi)
4. [Create the Bootable Media](#manual-step-4-create-the-bootable-media)
5. [Gather and Create Seed Files](#manual-step-5-gather--create-seed-files)
6. [Generate the Configuration Payload](#manual-step-6-configuration-payload)
7. [Enable networking on first boot of the livecd](#manual-step-7-enable-networking-on-first-boot-of-the-livecd)
8. [Populate the LiveCD with the payload](#manual-step-8-populate-the-livecd)
9. [Boot into the LiveCD](#manual-step-9-boot-into-your-livecd)

### Manual Step 1: Setup `csi`

Create a file with environmental variables in it.  These are example values, but set these to what you need for your system:

```bash
vim vars.sh
```

```bash
#!/bin/bash
export SYSTEM_NAME=drax
export PIT_USB_DEVICE=/dev/sdd
export PIT_DATA_LABEL=/dev/disk/by-label/PITDATA
export PIT_DATA_MOUNT=/mnt/pitdata
export PIT_COW_LABEL=/dev/disk/by-label/PITCOW
export PIT_COW_MOUNT=/mnt/pitcow

# URLs for resources needed
export PIT_REPO_URL=https://stash.us.cray.com/scm/mtl/cray-pre-install-toolkit.git
export PIT_REPO_FOLDER=$(basename $PIT_REPO_URL)
export PIT_WRITE_SCRIPT=/root/${PIT_REPO_FOLDER%%.git}/scripts/write-livecd.sh

# SET THESE TO THE APPROPRIATE PATHS IN THE RELEASE TARBALL
export UNSTABLE_RELEASE=0.6.1-alpha.1
export STABLE_RELEASE=0.7.1
export CSM_UNSTABLE=csm-$UNSTABLE_RELEASE
export CSM_STABLE=csm-$STABLE_RELEASE
export UNSTABLE_TARBALL=https://arti.dev.cray.com/artifactory/csm-distribution-unstable-local/$CSM_UNSTABLE.tar.gz
export STABLE_TARBALL=https://arti.dev.cray.com/artifactory/csm-distribution-stable-local/$CSM_STABLE.tar.gz
export PIT_ISO_NAME=$(pwd)/${CSM_STABLE}/cray-pre-install-toolkit-latest.iso
export PIT_K8S_DIR=$(pwd)/${CSM_STABLE}/images/kubernetes/
export PIT_CEPH_DIR=$(pwd)/${CSM_STABLE}/images/storage-ceph/

# Set to false for manual validation per the manual-steps, or set to true for CSI to validate automatically.
export PIT_VALIDATE_CEPH=false
export PIT_VALIDATE_DNS_DHCP=false
export PIT_VALIDATE_K8S=false
export PIT_VALIDATE_MTU=false
export PIT_VALIDATE_NETWORK=false
export PIT_VALIDATE_SERVICES=false
```

Now load the newly created file:

```bash
linux:~ $ source vars.sh
```

### Manual Step 2: Download and Expand the CSM Release

Download the CSM release tarball from the stable or unstable stream in artifactory.

```bash
# Unstable
cd /root
wget https://arti.dev.cray.com/artifactory/csm-distribution-unstable-local/${CSM_UNSTABLE}.tar.gz #csi pit get . $CSM_UNSTABLE
```

```bash
# Stable
cd /root
wget https://arti.dev.cray.com/artifactory/csm-distribution-stable-local/${CSM_STABLE}.tar.gz #csi pit get . $CSM_STABLE
```

Expand the tarball

```bash
tar -zxvf ${CSM_STABLE}.tar.gz
```

### Manual Step 3: Install `csi`

```bash
zypper --no-gpg-checks --plus-repo ./${CSM_STABLE}/rpm/csm-sle-15sp2/ -n in cray-site-init
```

### Manual Step 4: Create the Bootable Media

1. Fetch artifacts and format the USB device

```bash
# Clone the script, CSI will auto-search for this at /root/
git clone $PIT_REPO_URL

# Make the USB. This example creates a 50GB partition.  ~15-30GB is currently needed for the release tarball
csi pit format $PIT_USB_DEVICE $PIT_ISO_NAME 50000
```

2. Create and mount the partitions needed:

```bash
mkdir -pv $PIT_DATA_MOUNT $PIT_COW_MOUNT
mount $PIT_DATA_LABEL $PIT_DATA_MOUNT
mount $PIT_COW_LABEL $PIT_COW_MOUNT
```

### Manual Step 5: Gather / Create Seed Files

This is the set of files that you will currently need to create or find to generate the config payload for the system

1. `ncn_metadata.csv` (NCN configuration)
2. `hmn_connections.json` (RedFish configuration)
3. `switch_metadata.csv` (Switch configuration)

From these three files, you can run `csi config init` and it will generate all of the necessary config files needed for begining an install.

#### ncn_metadata.csv

Create `ncn_metadata.csv` by referencing these two pages:

- [NCN Metadata BMC](301-NCN-METADATA-BMC.md)
- [NCN Metadata BONDX](302-NCN-METADATA-BONDX.md)

#### hmn_connections.json

Create [hmn_connections.json](307-HMN-CONNECTIONS.md) by running a container against the CCD/SHCD spreadsheet.

#### switch_metadata.csv

Create [switch_metadata.csv](305-SWITCH-METADATA.md).

### Manual Step 6: Configuration Payload

The configuration payload comes from the `csi config init` command below.

1.  To execute this command you will need the following:

> The hsn_connections.json, ncn_metadata.csv, and switch_metadata.csv files in the current directory as well as values for the flags listed below.

> An example of the command to run with the required options.

```bash
linux:~ $ csi config init \
    --bootstrap-ncn-bmc-user root \
    --bootstrap-ncn-bmc-pass changeme \
    --system-name eniac  \
    --mountain-cabinets 0 \
    --river-cabinets 1  \
    --can-cidr 10.103.11.0/24 \
    --can-gateway 10.103.11.1/24 \
    --can-static-pool 10.103.11.112/28 \
    --can-dynamic-pool 10.103.11.128/25 \
    --nmn-cidr 10.252.0.0/17 \
    --hmn-cidr 10.254.0.0/17 \
    --ntp-pool time.nist.gov \
    --site-ip 172.30.53.79/20 \
    --site-gw 172.30.48.1 \
    --site-nic lan0 \
    --site-dns 172.30.84.40 \
    --install-ncn-bond-members p1p1,p10p1
```

This will generate the following files in a subdirectory with the system name.

```bash
linux:~ # ls -R $system_name
foo/:
basecamp  conman.conf  cpt-files  credentials  dnsmasq.d  manufacturing  metallb.yaml  networks  sls_input_file.json  system_config

foo/basecamp:
data.json

foo/cpt-files:
ifcfg-bond0  ifcfg-lan0  ifcfg-vlan002  ifcfg-vlan004  ifcfg-vlan007

foo/credentials:
bmc_password.json  mgmt_switch_password.json  root_password.json

foo/dnsmasq.d:
CAN.conf  HMN.conf  mtl.conf  NMN.conf  statics.conf

foo/manufacturing:

foo/networks:
CAN.yaml  HMNLB.yaml  HMN.yaml  HSN.yaml  MTL.yaml  NMNLB.yaml  NMN.yaml
```

2. Apply workarounds

Check for workarounds in the `/root/$CSM_RELEASE/fix/csi-config` directory.  If there are any workarounds in that directory, run those now.   Instructions are in the README files.

```bash
# Example
linux:~ # ls /root/$CSM_RELEASE/fix/csi-config
casminst-294  casminst-431  casminst-495  casminst-526
```

### Manual Step 7: Enable networking on first boot of the liveCD

This is accomplished by populating the PITCOW partition with the necessary config files generated by `csi`

```bash
csi pit populate pitcow $PIT_COW_MOUNT ${SYSTEM_NAME}/
```

```
config------------------------> /mnt/pitcow/rw/etc/sysconfig/network/config...OK
ifcfg-bond0-------------------> /mnt/pitcow/rw/etc/sysconfig/network/ifcfg-bond0...OK
ifcfg-lan0--------------------> /mnt/pitcow/rw/etc/sysconfig/network/ifcfg-lan0...OK
ifcfg-vlan002-----------------> /mnt/pitcow/rw/etc/sysconfig/network/ifcfg-vlan002...OK
ifcfg-vlan004-----------------> /mnt/pitcow/rw/etc/sysconfig/network/ifcfg-vlan004...OK
ifcfg-vlan007-----------------> /mnt/pitcow/rw/etc/sysconfig/network/ifcfg-vlan007...OK
ifroute-lan0------------------> /mnt/pitcow/rw/etc/sysconfig/network/ifroute-lan0...OK
ifroute-vlan002---------------> /mnt/pitcow/rw/etc/sysconfig/network/ifroute-vlan002...OK
CAN.conf----------------------> /mnt/pitcow/rw/etc/dnsmasq.d/CAN.conf...OK
HMN.conf----------------------> /mnt/pitcow/rw/etc/dnsmasq.d/HMN.conf...OK
NMN.conf----------------------> /mnt/pitcow/rw/etc/dnsmasq.d/NMN.conf...OK
mtl.conf----------------------> /mnt/pitcow/rw/etc/dnsmasq.d/mtl.conf...OK
statics.conf------------------> /mnt/pitcow/rw/etc/dnsmasq.d/statics.conf...OK
```

### Manual Step 8: Populate the LiveCD

> NOTE:  When running on a system that has 1.3 installed, you may hit a collision with an ip rule that prevents access to arti.dev.cray.com.  If you cannot ping that name, try removing this ip rule: `ip rule del from all to 10.100.0.0/17 lookup rt_smnet`

Populate your live cd with the kernel, initrd, and squashfs images (KIS), as well as the basecamp configs and any files you may have in your dir that you'll want on the livecd.

```bash
# Copy basecamp data
csi pit populate pitdata $PIT_DATA_MOUNT ${SYSTEM_NAME} -b
# Copy kernel to data dir
csi pit populate pitdata $PIT_DATA_MOUNT $PIT_CEPH_DIR -k
# Copy initrd to data dir
csi pit populate pitdata $PIT_DATA_MOUNT $PIT_CEPH_DIR -i
# Copy ceph image to ceph dir
csi pit populate pitdata $PIT_DATA_MOUNT $PIT_CEPH_DIR -C
# Copy kube image to k8s dir
csi pit populate pitdata $PIT_DATA_MOUNT $PIT_K8S_DIR -K
# Copy any files in the current dir to the prep dir (example: copying over your three config files or vars.sh file)
csi pit populate pitdata $PIT_DATA_MOUNT . -p

# Copy the expanded tarball into the data partition
linux:~ # cp -r /root/$CSM_RELEASE $PIT_PREP_DIR
```

### Manual Step 9: Boot into your LiveCD.

Now you can boot into your LiveCD [LiveCD Startup](003-LIVECD-STARTUP.md)
