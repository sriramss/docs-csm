# LiveCD Setup

This page will assist you with configuring the LiveCD, a.k.a. CRAY Pre-Install Toolkit.

### Requirements:

Before starting, you should have:

1. A USB stick or other Block Device, local to ncn-m001.
   - The block device should be `>=256GB`
2. The drive letter of that device (i.e. `/dev/sdd`)
3. If you are installing a system that previously had 1.3 installed, move external network connections from ncn-w001 to ncn-m001
   - See [MOVE-SITE-CONNECTIONS](050-MOVE-SITE-CONNECTIONS.md).
4. Access to stash/bitbucket
5. A CSM release tarball

To begin these LiveCD creation steps, you must be logged in to an operating system that is running on the disk of ncn-m001.  You should not be on the LiveCD running on the USB stick or other block device.

### Steps:

> NOTE: These steps will be automated. CASM/MTL is automating this process  with the cray-site-init tool.

1. [Download and expand the CSM release](#manual-step-1-download-and-expand-the-csm-release)
2. [Install `csi`](#manual-step-2-install-csi)
3. [Setup ENV vars for use with `csi`](#manual-step-3-setup-csi)
4. [Create the Bootable Media](#manual-step-4-create-the-bootable-media)
5. [Gather and Create Seed Files](#manual-step-5-gather-create-seed-files)
6. [Generate the Configuration Payload](#manual-step-6-configuration-payload)
7. [Generate the Data Payload](#manual-step-7-data-payload)
8. [Boot into the LiveCD](#manual-step-8-boot-into-your-livecd)

## Manual Step 1: Download and Expand the CSM Release

Download the CSM release tarball from the stable or unstable stream in artifactory.

```bash
# Unstable
csm_release=csm-0.0.0-alpha.1
cd /root
wget https://arti.dev.cray.com/artifactory/csm-distribution-unstable-local/${csm_release}.tar.gz
```

```bash
# Stable
csm_release=csm-0.0.0
cd /root
wget https://arti.dev.cray.com/artifactory/csm-distribution-stable-local/${csm_release}.tar.gz
```

Expand the tarball

```bash
tar -zxvf ${csm_release}.tar.gz
```

## Manual Step 2: Install `csi`

```bash
zypper --no-gpg-checks --plus-repo ./${csm_release}/rpm/csm-sle-15sp2/ -n in cray-site-init
```

## Manual Step 3: Setup `csi`

Create a file with a bunch of environmental variables in it.  These are example values, but set these to what you need for your system:

```bash
vim vars.sh
```

```bash
#!/bin/bash
# These vars will likely stay the same unless there are development changes
export PIT_USB_DEVICE=/dev/sdd
export PIT_DISK_LABEL=/dev/disk/by-label/PITDATA
export PIT_REPO_URL=https://stash.us.cray.com/scm/mtl/cray-pre-install-toolkit.git

# These are the artifacts you want to be used to boot with
export PIT_WRITE_SCRIPT=$(pwd)/cray-pre-install-toolkit/scripts/write-livecd.sh
export PIT_DATA_DIR=/mnt/data
export PIT_PREP_DIR=/mnt/prep
export PIT_CONFIGS_DIR=/mnt/configs
export PIT_CEPH_DIR=/mnt/data/ceph
export PIT_K8S_DIR=/mnt/data/k8s

# SET THESE TO THE APPROPRIATE PATHS IN THE RELEASE TARBALL
export CSM_RELEASE=csm-0.0.0-rc1
export PIT_ISO_IMAGE=$(pwd)/$CSM_RELEASE/cray-pre-install-toolkit-latest.iso
export PIT_INITRD_IMAGE=$PIT_PREP_DIR/$CSM_RELEASE/images/storage-ceph/initrd.img-0.0.4.xz
export PIT_KERNEL_IMAGE=$PIT_PREP_DIR/$CSM_RELEASE/images/storage-ceph/5.3.18-24.37-default-0.0.4.kernel

export PIT_STORAGE_IMAGE=$PIT_PREP_DIR/$CSM_RELEASE/images/storage-ceph/storage-ceph-0.0.4.squashfs
export PIT_MANAGER_IMAGE=$PIT_PREP_DIR/$CSM_RELEASE/images/kubernetes/kubernetes-0.0.5.squashfs

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

We'll also load this into the LiveCD USB in a later step so we can use it again.

## Manual Step 4: Create the Bootable Media

1. Make the USB and fetch artifacts.

    TODO:  get write-livecd.sh into the release tarball so we no longer need to clone the repo

    ```bash
    # Clone the script, CSI will auto-search for this in your current directory
    git clone $PIT_REPO_URL

    # Make the USB.
    csi pit format $PIT_USB_DEVICE $PIT_ISO_IMAGE 20000
    ```

2. Mount data partition:

    ```bash
    mount $PIT_DISK_LABEL /mnt
    ```

    Now that your disk is setup and the data partition is mounted, you can begin gathering info and configs and populating it to the USB disk so it's available when you boot into the livecd.

3. Make the config and data directories, and a prep directory for our manual files:
    ```bash
   mkdir -pv $PIT_CONFIGS_DIR $PIT_PREP_DIR $PIT_CEPH_DIR $PIT_K8S_DIR
   ```

4. Copy your vars file to the data partition

    ```bash
    cp vars.sh $PIT_PREP_DIR
    ```

> Note: We will unmount this device at the end of this page. For now, leave it mounted.

## Manual Step 5: Gather / Create Seed Files

This is the set of files that you will currently need to create or find to generate the config payload for the system

  1. `ncn_metadata.csv` (NCN configuration)
  2. `hmn_connections.json` (RedFish configuration)
  3. `switch_metadata.csv` (Switch configuration)

#### ncn_metadata.csv

See [NCN Metadata BMC](301-NCN-METADATA-BMC.md) and [NCN Metadata BONDX](302-NCN-METADATA-BONDX.md) for information on creating this file.
The format of this file has changed so make sure the column headings of your file match those shown in these two pages.

When you have this file, add it into the prep directory:

```bash
linux:~ # cp ncn_metadata.csv $PIT_PREP_DIR
```

#### hmn_connections.json

- TODO: Move this section into 300-350 service guides.
- TODO: Give context for xlsx file instead of surprising user with new dependency.

This file should come from the [shasta_system_configs](https://stash.us.cray.com/projects/DST/repos/shasta_system_configs/browse) repository.
Each system has its own directory in the repository. If this is a new system that doesn't yet have the `hmn_connections.json` file,
 then one will need to be generated from the CCD/SHCD (Cabling Diagram) for the system.

If you do not have this file you can use Docker to generate a new one.

If you need to fetch the cabling diagram, you can use CrayAD logins to fetch it from [SharePoint](http://inside.us.cray.com/depts/CustomerService/CID/Install%20Documents/Forms/AllItems.aspx?RootFolder=%2Fdepts%2FCustomerService%2FCID%2FInstall%20Documents%2FCray%2FShasta%20River&FolderCTID=0x012000C5B40D5925B4534FA7D60FAF1F12BAE9&View={79A8C99F-11EB-44B8-B1A6-02D02755BFC4}).

> NOTE: Docker is available on 1.3 systems if you're making the LiveCD from there. Otherwise, you can install this through zypper or find out how through [Docker's documentation](https://docs.docker.com/desktop/)

```bash
# Replace `${shcd_path}` with the absolute path to the latest CID for the system.
linux:~ # docker run --rm -it --name hms-shcd-parser -v  ${shcd_path}:/input/shcd_file.xlsx -v $(pwd):/output dtr.dev.cray.com/cray/hms-shcd-parser:latest
```

Your files should appear in a `./output` directory, relative to where you ran the `docker` command. These files should be copied into the LiveCD:

```bash
linux:~ # cp -r output/* $PIT_PREP_DIR
```

#### switch_metadata.csv

This file is manually created right now and follows this format:

```
Switch Xname,Type,Brand
x3000c0w18,Leaf,Dell
x3000c0h19s1,Spine,Mellanox
x3000c0h19s2,Spine,Mellanox
```

For information on creating file see [NCN Switch Metadata](305-SWITCH-METADATA.md).

Once you have your file, copy this into the $PIT_PREP_DIR for safe-keeping:
```bash
linux:~ # cp -r your_switch_metadata.csv $PIT_PREP_DIR
```

## Manual Step 6: Configuration Payload

Now we need to generate our configuration payload around our system's schema. We now need:

- The number of mountain and river cabinets in the system.
- A set of confiugration information sufficient to fill out the listed flags

The configuration payload comes from the `csi config init` command below.

```bash
linux:~ $ cd $PIT_PREP_DIR
```

1.  To execute this command you will need the following:
    > An example of the command to run with the required options.
    > The hsn_connections.json, ncn_metadata.csv, and switch_metadata.csv files in the current directory.

    Now generate the files:

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
    ifcfg-bond0  ifcfg-lan0  ifcfg-vlan002  ifcfg-vlan004  ifcfg-vlan007 ifroute-vlan002

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

3. Copy the `data.json` into the configs directory on the data partition.

    ```bash
    cp /mnt/prep/${system_name}/basecamp/data.json $PIT_CONFIGS_DIR
    ```

## Manual Step 7: Data Payload

We'll use the previously defined URLs in `vars.sh` to fetch our data payload.

> NOTE:  When running on a system that has 1.3 installed, you may hit a collision with an ip rule that prevents access to arti.dev.cray.com.  If you cannot ping that name, try removing this ip rule:
    `ip rule del from all to 10.100.0.0/17 lookup rt_smnet`

This will fetch to your bootable USB:

```bash
# If you didn't earlier:
linux:~ # source /mnt/prep/vars.sh

# Copy the expanded tarball into the data partition
linux:~ # cp -r /root/$CSM_RELEASE $PIT_PREP_DIR

# Place the images:
linux:~ # cp $PIT_INITRD_IMAGE $PIT_DATA_DIR
linux:~ # cp $PIT_KERNEL_IMAGE $PIT_DATA_DIR
linux:~ # cp $PIT_STORAGE_IMAGE $PIT_CEPH_DIR
linux:~ # cp $PIT_MANAGER_IMAGE $PIT_K8S_DIR

# Check what is there:
linux:~ # ls -lR $PIT_DATA_DIR

```

Now, unmount the bootable USB.

```bash
linux:~ # umount /mnt
```

## Manual Step 8 : Boot into your LiveCD.

Now you can boot into your LiveCD [LiveCD Startup](003-LIVECD-STARTUP.md)
