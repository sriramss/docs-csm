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
5. `csi` installed (get the [latest built rpm](http://dst.us.cray.com/dstrepo/shasta-cd-repo/bloblets/csm/rpms/csm-sle-15sp2/))

### Steps:

> NOTE: These steps will be automated. CASM/MTL is automating this process  with the cray-site-init tool.

1. [Install `csi`](#manual-step-1-install-csi)
2. [Setup ENV vars for use with `csi`](#manual-step-2-setup-csi)
3. [Create the Bootable Media](#manual-step-3-create-the-bootable-media)
4. [Gather and Create Seed Files](#manual-step-4-gather--create-seed-files)
5. [Generate the Configuration Payload](#manual-step-5-configuration-payload)
6. [Generate the Data Payload](#manual-step-6-data-payload)
7. [Boot into the LiveCD](#manual-step-7--boot-into-your-livecd)

## Manual Step 1: Install `csi`

##### OpenSuSE / SLES

```bash
zypper --no-gpg-checks --plus-repo http://dst.us.cray.com/dstrepo/shasta-cd-repo/bloblets/csm/rpms/csm-sle-15sp2/ -n in cray-site-init
```

> NOTE: Alternatively, you can find the RPM in this repository and install it with the `rpm` command.
> http://dst.us.cray.com/dstrepo/shasta-cd-repo/bloblets/csm/rpms/csm-sle-15sp2

## Manual Step 2: Setup `csi`

Create a file with a bunch of environmental variables in it.  These are example values, but set these to what you need for your system:

For fetching image information, see [NCN Images](100-NCN-IMAGES.md).

```bash
vim vars.sh
```

```bash
#!/bin/bash
# These vars will likely stay the same unless there are development changes
export PIT_USB_DEVICE=/dev/sdd
export PIT_DISK_LABEL=/dev/disk/by-label/PITDATA
export PIT_REPO_URL=https://stash.us.cray.com/scm/mtl/cray-pre-install-toolkit.git
export PIT_ISO_URL=http://car.dev.cray.com/artifactory/csm/MTL/sle15_sp2_ncn/x86_64/dev/master/metal-team/cray-pre-install-toolkit-latest.iso
export PIT_ISO_NAME=$(basename $PIT_ISO_URL)

# These are the artifacts you want to be used to boot with
export PIT_WRITE_SCRIPT=/root/cray-pre-install-toolkit/scripts/write-livecd.sh
export PIT_DATA_DIR=/mnt/data
export PIT_PREP_DIR=/mnt/prep
export PIT_CONFIGS_DIR=/mnt/configs
export PIT_CEPH_DIR=/mnt/data/ceph
export PIT_K8S_DIR=/mnt/data/k8s

# THESE WILL LIKELY NEED TO BE MODIFIED!
# Latest stable base.
export PIT_INITRD_URL=https://arti.dev.cray.com/artifactory/node-images-stable-local/shasta/non-compute-common/0.0.4/initrd.img-0.0.4.xz
export PIT_KERNEL_URL=https://arti.dev.cray.com/artifactory/node-images-stable-local/shasta/non-compute-common/0.0.4/5.3.18-24.37-default-0.0.4.kernel

# Latest development/unstable k8s/ceph (built atop latest stable base).
export PIT_MANAGER_URL=https://arti.dev.cray.com/artifactory/node-images-unstable-local/shasta/kubernetes/0.0.4-2/kubernetes-0.0.4-2.squashfs
export PIT_STORAGE_URL=https://arti.dev.cray.com/artifactory/node-images-unstable-local/shasta/storage-ceph/0.0.3-2/storage-ceph-0.0.3-2.squashfs

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

## Manual Step 3: Create the Bootable Media

1. Make the USB and fetch artifacts.

    ```bash
    # Find your USB stick with your linux tool of choice, for this example it is /dev/sdd
    wget $PIT_ISO_URL      

    # Clone the script, CSI will auto-search for this at /root/
    git clone $PIT_REPO_URL

    # Make the USB.
    csi pit format $PIT_USB_DEVICE ./cray-pre-install-toolkit-latest.iso 20000
    ```

2. Mount data partition:

    ```bash
    mount $PIT_DISK_LABEL /mnt
    ```

    Now that your disk is setup and the data partition is mounted, you can begin gathering info and configs and populating it to the USB disk so it's available when you boot into the livecd.

3. Make the config and data directories, and a prep directory for our manual files:
    ```bash
   mkdir -pv $PIT_CONFIGS_DIR $PIT_DATA_DIR $PIT_PREP_DIR
   ```

4. Copy your vars file to the data partition

    ```bash
    cp vars.sh $PIT_PREP_DIR
    ```

> Note: We will unmount this device at the end of this page. For now, leave it mounted.

## Manual Step 4: Gather / Create Seed Files

This is the set of files that you will currently need to create or find to generate the config payload for the system

  1. `ncn_metadata.csv` (NCN configuration)
  2. `hmn_connections.json` (RedFish configuration)
  3. `switch_metadata.csv` (Switch configuration)
  4. `qnd-1.4.sh` (LiveCD configuration - shasta-1.4 shim for automation)

file (see below) to configure the LiveCD node.

#### qnd-1.4.sh

You will need to create the `qnd-1.4.sh` file with the following contents, replacing values with those specific to your system:

```bash
export site_nic=em1
export site_cidr=172.30.52.220/20
export site_gw=172.30.48.1
export site_dns=172.30.84.40
export can_cidr=10.102.4.0/24
export can_gw=10.102.4.111
export can_static=10.102.9.112/28
export can_dynamic=10.102.9.128/25
export ntp_pool=time.nist.gov
export system_name=sif
export username=root
export password=changemetoday!
```

- `site_nic` The interface that is directly attached to the site network on ncn-m001.
- `site_cidr` The IP address and netmask in CIDR notation that is assigned to the site connection on ncn-m001.  NOTE:  This is NOT just the network, but also the IP address.
- `site_gw` The gateway address for the site network.  This will be used to set up the default gateway route on ncn-m001.
- `site_dns` ONE of the site DNS servers.   The script does not currently handle setting more than one IP address here.
- `can_cidr` The IP subnet for the CAN network assigned to this system.  Customer Access Network information will need to be gathered by hand. (For current BGP Dev status, see [Can BGP status on Shasta systems](https://connect.us.cray.com/confluence/display/CASMPET/CAN-BGP+status+on+Shasta+systems))
- `can_gw`  The common gateway IP used for both spine switches.   Also commonly referred to as the Virtual IP for the CAN.
- `can_static` and `can_dynamic` The MetalLB address static and dynamic address pools for the customer access network
- `ntp_pool` is the upstream time server
- `system_name` is the system name
- `username` is the BMC username
- `password` is the BMC password

Copy this file to the mounted data partition.

```bash
linux:~ # cp qnd-1.4.sh $PIT_PREP_DIR
```

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

## Manual Step 5: Configuration Payload

Now we need to generate our configuration payload around our system's schema. We now need:

- The number of mountain and river cabinets in the system.
- The variables defined in qnd-1.4.sh above.

The configuration payload comes from the `csi config init` command below.

```bash
linux:~ $ cd $PIT_PREP_DIR
linux:~ $ source qnd-1.4.sh
```

1.  To execute this command you will need the following:
    > An example of the command to run with the required options.
    > The hsn_connections.json, ncn_metadata.csv, and switch_metadata.csv files in the current directory.

    Now generate the files:
    ```bash
    linux:~ $ csi config init \
        --bootstrap-ncn-bmc-user $username \
        --bootstrap-ncn-bmc-pass $password \
        --system-name $system_name \
        --mountain-cabinets 0 \
        --river-cabinets 1 \
        --can-cidr $can_cidr \
        --can-gateway $can_gw \
        --can-static-pool $can_static \
        --can-dynamic-pool $can_dynamic \
        --ntp-pool $ntp_pool
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

    Clone the workaround repo to have access to the workarounds needed to get through some known issues until they are fully fixed.

    ```bash
    pit:~ # cd /root
    pit:~ # git clone https://stash.us.cray.com/scm/spet/csm-installer-workarounds.git
    ```

    If there are any workarounds in the csi-config directory, run those now.   Instructions are in the README files.

3. Validate `data.json` to sanitize any human-error:

    ```bash
    cat /mnt/prep/${system_name}/basecamp/data.json | jq
    ```

    If you do not see an error message, the format is valid.

4. Copy the `data.json` into the configs directory on the data partition.

    ```bash
    cp /mnt/prep/${system_name}/basecamp/data.json $PIT_CONFIGS_DIR
    ```

## Manual Step 6: Data Payload

We'll use the previously defined URLs in `vars.sh` to fetch our data payload.

> NOTE:  When running on a system that has 1.3 installed, you may hit a collision with an ip rule that prevents access to arti.dev.cray.com.  If you cannot ping that name, try removing this ip rule:
    `ip rule del from all to 10.100.0.0/17 lookup rt_smnet`

This will fetch to your bootable USB:

```bash
# If you didn't earlier:
linux:~ # source /mnt/prep/vars.sh

# Then download the artifacts:
linux:~ # csi pit get

# Check what downloaded:
linux:~ # ls -lR $PIT_DATA_DIR
```

Now, unmount the bootable USB.

```bash
linux:~ # umount /mnt
```

## Manual Step 7 : Boot into your LiveCD.

Now you can boot into your LiveCD [LiveCD Startup](003-LIVECD-STARTUP.md)
