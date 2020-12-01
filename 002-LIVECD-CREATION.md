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
5. `csi` installed (get the [latest built rpm](http://dst.us.cray.com/dstrepo/shasta-cd-repo/bloblets/csm/rpms/cray-sles15-sp2-ncn/))

### Steps:

> NOTE: These steps will be automated. CASM/MTL is automating this process  with the cray-site-init tool.

1. [Install `csi`](#manual-step-1-install-csi)
2. [Setup ENV vars for use with `csi`](#manual-step-2-setup-csi)
3. [Create the Bootable Media](#manual-step-3-create-the-bootable-media)
4. [Gather and Create Seed Files](#manual-step-4-gather--create-seed-files)
5. [Generate the Configuration Payload](#manual-step-5-configuration-payload)
6. [Generate the Data Payload](#manual-step-6-data-payload)
7. [Shutdown NCNs](#manual-step-7--shutdown-ncns)
8. [Boot into the LiveCD](#manual-step-8--boot-into-your-livecd)

## Manual Step 1: Install `csi`

##### OpenSuSE / SLES

```bash
zypper --no-gpg-checks --plus-repo http://dst.us.cray.com/dstrepo/shasta-cd-repo/bloblets/csm/rpms/cray-sles15-sp2-ncn/ -n in cray-site-init
```

> NOTE: Alternatively, you can find the RPM in this repository and install it with the `rpm` command.
> http://dst.us.cray.com/dstrepo/shasta-cd-repo/bloblets/csm/rpms/cray-sles15-sp2-ncn

## Manual Step 2: Setup `csi`

Create a file with a bunch of environmental variables in it.  These are example values, but set these to what you need for your system:

For fetching image information, see [NCN Images](100-NCN-IMAGES.md).

```bash
vim vars.sh
```

```bash
#!/bin/bash
# These vars will likely stay the same unless there are development changes
export PIT_DISK_LABEL=/dev/disk/by-label/PITDATA
export PIT_REPO_URL=https://stash.us.cray.com/scm/mtl/cray-pre-install-toolkit.git
export PIT_ISO_URL=http://car.dev.cray.com/artifactory/internal/MTL/sle15_sp2_ncn/x86_64/dev/master/metal-team/cray-pre-install-toolkit-latest.iso
export PIT_ISO_NAME=$(basename $PIT_ISO_URL)

# These are the artifacts you want to be used to boot with
export PIT_WRITE_SCRIPT=/root/cray-pre-install-toolkit/scripts/write-livecd.sh
export PIT_DATA_DIR=/mnt/data
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
    csi pit format /dev/sdd ./cray-pre-install-toolkit-latest.iso 20000 
    ```
   
   > Note: If this fails to find the creation script then [CASMINST-285](https://connect.us.cray.com/jira/browse/CASMINST-285) may be present. Regardless, you can specify the script with `-w` if you've cloned it manually with `git clone $PIT_REPO_URL`.

2. Mount data partition:

    ```bash
    mount /dev/disk/by-label/PITDATA /mnt
    ```

    Now that your disk is setup and the data partition is mounted, you can begin gathering info and configs and populating it to the USB disk so it's available when you boot into the livecd.

3. Make the config and data directories, and a prep directory for our manual files:
    ```bash
   mkdir -pv /mnt/configs /mnt/data /mnt/prep
   ```

4. Copy your vars file to the data partition

    ```bash
    cp vars.sh /mnt/prep/
    ```

> Note: We will unmount this device at the end of this page. For now, leave it mounted.

## Manual Step 4: Gather / Create Seed Files

This is the set of files that you will currently need to create or find to generate the config payload for the system

  1. `ncn_metadata.csv` (NCN configuration)
  2. `hmn_connections.json` (RedFish configuration)
  3. `qnd-1.4.sh` (LiveCD configuration - shasta-1.4 shim for automation)

file (see below) to configure the LiveCD node.

#### qnd-1.4.sh

You will need to create the `qnd-1.4.sh` file with the following contents, replacing values with those specific to your system:

```bash
export site_nic=em1
export site_cidr=172.30.52.220/20
export site_gw=172.30.48.1
export site_dns=172.30.84.40
export bond_member0=p801p1
export bond_member1=p801p2
export mtl_cidr=10.1.1.1/16
export nmn_cidr=10.252.0.10/17
export hmn_cidr=10.254.0.10/17
export can_cidr=10.102.4.110/24
export system_name=sif
```

- `site_nic` The interface that is directly attached to the site network on ncn-m001.
- `site_cidr` The IP address and netmask in CIDR notation that is assigned to the site connection on ncn-m001.  NOTE:  This is NOT just the network, but also the IP address.
- `site_gw` The gateway address for the site network.  This will be used to set up the default gateway route on ncn-m001.
- `site_dns` ONE of the site DNS servers.   The script does not currently handle setting more than one IP address here.
- `bond_member0` and `bond_member1` The two interfaces that will be bonded to the bond0 interface.
- `mtl_cidr`, `nmn_cidr`, `hmn_cidr`, and `can_cidr` The IP address and netmask in CIDR notation that is assigned to the bond0, vlan002, vlan004, and vlan007 interfaces on the LiveCD, respectively.  NOTE:  These include the IP address AND the netmask.  It is not just the network CIDR. Customer Access Network information will need to be gathered by hand. (For current BGP Dev status, see [Can BGP status on Shasta systems](https://connect.us.cray.com/confluence/display/CASMPET/CAN-BGP+status+on+Shasta+systems))

Copy this file to the mounted data partition.

```bash
linux:~ # cp qnd-1.4.sh /mnt/prep/
```

#### ncn_metadata.csv

See [NCN Metadata BMC](301-NCN-METADATA-BMC.md) and [NCN Metadata BONDX](302-NCN-METADATA-BONDX.md) for information on creating this file.

When you have this file, add it into the prep directory:

```bash
linux:~ # cp ncn_metadata.csv /mnt/prep/
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
linux:~ # cp -r output/* /mnt/prep/
```

## Manual Step 5: Configuration Payload

Now we need to generate our configuration payload around our system's schema. We now need:

- The username and password for the BMCs (normally, root and initial0)
- xnames for the spine and leaf switches. x3000c0wXX where XX is the slot in the rack (see [HSS Naming Convention](https://connect.us.cray.com/confluence/display/HSOS/Shasta+HSS+Component+Naming+Convention?)))
- The number of mountain and river cabinets in the system.

The configuration payload comes from the `csi config init` command anywhere.

> NOTE: If you have not done so already, you must `source qnd-1.4.sh` to load vars such as the `$can_cidr`. 

1.  To execute this command you will need the following:
    > An example of the command to run with the required options.

    Example variables to use
    ``` bash
    username=root
    password=changemetoday!
    crayname=foo
    leafnames=x3000c0w14
    spinenames=x3000c0w12,x3000c0w13
    ```

    Now generate the files:
    ```bash
    linux:~ $ csi config init \
        --bootstrap-ncn-bmc-user $username \
        --bootstrap-ncn-bmc-pass $password \
        --leaf-switch-xnames $leafnames \
        --spine-switch-xnames $spinenames \
        --system-name $crayname \
        --mountain-cabinets 0 \
        --river-cabinets 1 \
        --can-cidr $can_cidr
    ```

    This will generate the following files in a subdirectory with the system name.

    ```bash
    linux:~ # ls -R $crayname
    foo:
    conman.conf  data.json      dnsmasq.d      metallb.yaml      sls_input_file.json
    credentials  manufacturing  networks       system_config.yaml

    foo/credentials:
    bmc_password.json  mgmt_switch_password.json  root_password.json

    foo/dnsmasq.d:
    CAN.conf  HMN.conf  mtl.conf  NMN.conf	statics.conf

    foo/manufacturing:

    foo/networks:
    CAN.yaml  HMN.yaml  HSN.yaml  MTL.yaml	NMN.yaml
    ```

2. Apply work-arounds:

    - [CASMINST-298](https://connect.us.cray.com/jira/browse/CASMINST-298) 
        - First, generate a pretty `data.json` that is easier to edit.
          ```bash
          linux:~ # cp $crayname/data.json $crayname/data.json.orig
          cat $crayname/data.json.orig | python -mjson.tool > $crayname/data.json
          ```
    - [CASMINST-262](https://connect.us.cray.com/jira/browse/CASMINST-262) and [CASMINST-281](https://connect.us.cray.com/jira/browse/CASMINST-281)

        - Add `Global`, `Default`, `ncn-storage`, `ncn-master`, and `ncn-worker` sections to the end of `data.json` before the last curly bracket `}`.   Make sure to add a comma after the second-to-last curly bracket `{`.

        ```json
         },
         "Default": {
           "meta-data": {
             "foo": "bar",
             "shasta-role": "ncn-storage"
           },
           "user-data": {}
         },
         "ncn-storage": {
           "meta-data": {
             "ceph_version": "1.0",
             "self_destruct": "false"
           },
           "user-data": {
             "test": "123",
             "runcmd": [
               "echo This is a storage cmd $(date) > /opt/runcmd"
             ]
           }
         },
         "ncn-master": {
           "meta-data": {
             "self_destruct": "false"
           },
           "user-data": {
             "test": "123",
             "runcmd": [
               "echo This is a master cmd $(date) > /opt/runcmd"
             ]
           }
         },
         "ncn-worker": {
           "meta-data": {
             "self_destruct": "false"
           },
           "user-data": {
             "test": "123",
             "runcmd": [
               "echo This is a worker cmd $(date) > /opt/runcmd"
             ]
           }
         },
         "Global": {
           "meta-data": {
             "can-gw": "~FIXME~ e.g. 10.102.9.20",
             "can-if": "vlan007",
             "ceph-cephfs-image": "dtr.dev.cray.com/cray/cray-cephfs-provisioner:0.1.0-nautilus-1.3",
             "ceph-rbd-image": "dtr.dev.cray.com/cray/cray-rbd-provisioner:0.1.0-nautilus-1.3",
             "chart-repo": "http://helmrepo.dev.cray.com:8080",
             "dns-server": "~FIXME~ e.g. 10.252.1.1",
             "docker-image-registry": "dtr.dev.cray.com",
             "domain": "nmn hmn",
             "first-master-hostname": "~FIXME~ e.g. ncn-m002",
             "k8s-virtual-ip": "~FIXME~ e.g. 10.252.120.2",
             "kubernetes-max-pods-per-node": "200",
             "kubernetes-pods-cidr": "10.32.0.0/12",
             "kubernetes-services-cidr": "10.16.0.0/12",
             "kubernetes-weave-mtu": "1460",
             "ntp_local_nets": "~FIXME~ e.g. 10.252.0.0/17,10.254.0.0/17",
             "ntp_peers": "~FIXME~ e.g. ncn-w001 ncn-w002 ncn-w003 ncn-s001 ncn-s002 ncn-s003 ncn-m001 ncn-m002 ncn-m003",
             "num_storage_nodes": "3",
             "rgw-virtual-ip": "~FIXME~ e.g. 10.252.2.100",
           "upstream_ntp_server": "~FIXME~",
             "wipe-ceph-osds": "yes"
           }
         }
        }
        ```

    - [CASMINST-320](https://connect.us.cray.com/jira/browse/CASMINST-320)
        - Fix the customer-access-static and customer-access address pools to match what is in [Can BGP status on Shasta systems](https://connect.us.cray.com/confluence/display/CASMPET/CAN-BGP+status+on+Shasta+systems)
        - Set the hardware-management address pool to 10.94.100.0/24
       ```bash
        - name: hardware-management
          protocol: bgp
          addresses:
          - 10.94.100.0/24
       ```
      - Set the node-management address pool to 10.92.100.0/24
       ```bash
        - name: node-management
          protocol: bgp
          addresses:
          - 10.92.100.0/24
       ```

    - [CASMINST-294](https://connect.us.cray.com/jira/browse/CASMINST-294)

        - Add the MAC address for the MTL dhcp-host entry for each node in dnsmasq.d/statics.conf.   This should be the bond0 MAC (i.e. the same MAC as the one used for NMN, HMN, and CAN).
       ```bash
        # DHCP Entries for ncn-s002
        dhcp-host=14:02:ec:da:b9:38,10.252.0.154,ncn-s002,infinite # NMN
        dhcp-host=14:02:ec:da:b9:38,10.1.0.24,ncn-s002,infinite # MTL
        dhcp-host=14:02:ec:da:b9:38,10.254.0.154,ncn-s002,infinite # HMN
        dhcp-host=14:02:ec:da:b9:38,10.102.11.218,ncn-s002,infinite # CAN
        dhcp-host=94:40:c9:37:77:da,10.254.0.153,ncn-s002-mgmt,infinite #HMN
       ```

    - [CASMINST-321](https://connect.us.cray.com/jira/browse/CASMINST-321)

        - Fix the `router` option in CAN.conf to match the *gateway* IP address of vlan7 on this spines.   For Aruba switches, this is the `active-gateway ip`.   For Mellanox switches, this is the `magp` IP.
       ```bash
       sw-spine01# show running-config interface vlan 7
       interface vlan7
        vsx-sync active-gateways
        ip address 10.102.11.1/24
        active-gateway ip mac 12:01:00:00:01:00
        active-gateway ip 10.102.11.111
        ip mtu 9198
        exit
       ```
    
       ```bash
       dhcp-option=interface:vlan004,option:router,10.102.11.111
       ```

    - [CASMINST-251](https://connect.us.cray.com/jira/browse/CASMINST-251)

        - For NMN.conf, HMN.conf, CAN.conf, and mtl.conf, make sure the dhcp-range starts AFTER the IPs that are fixed in statics.conf.

        ```bash
        # Where 10.252 is the prefix to the NMN in this environment.
        linux:~ # grep 10.252 $crayname/dnsmasq.d/statics.conf
        dhcp-host=14:02:ec:d9:7a:90,10.252.0.153,ncn-s003,infinite # NMN
        host-record=ncn-s003,ncn-s003.nmn,10.252.0.153
        dhcp-host=14:02:ec:da:b9:38,10.252.0.154,ncn-s002,infinite # NMN
        host-record=ncn-s002,ncn-s002.nmn,10.252.0.154
        dhcp-host=14:02:ec:d9:77:a8,10.252.0.155,ncn-s001,infinite # NMN
        host-record=ncn-s001,ncn-s001.nmn,10.252.0.155
        dhcp-host=14:02:ec:d9:7a:30,10.252.0.156,ncn-w003,infinite # NMN
        host-record=ncn-w003,ncn-w003.nmn,10.252.0.156
        dhcp-host=14:02:ec:d9:7b:b0,10.252.0.157,ncn-w002,infinite # NMN
        host-record=ncn-w002,ncn-w002.nmn,10.252.0.157
        dhcp-host=14:02:ec:da:b7:28,10.252.0.158,ncn-w001,infinite # NMN
        host-record=ncn-w001,ncn-w001.nmn,10.252.0.158
        dhcp-host=14:02:ec:d9:79:a0,10.252.0.159,ncn-m003,infinite # NMN
        host-record=ncn-m003,ncn-m003.nmn,10.252.0.159
        dhcp-host=14:02:ec:d9:78:20,10.252.0.160,ncn-m002,infinite # NMN
        host-record=ncn-m002,ncn-m002.nmn,10.252.0.160
        dhcp-host=14:02:ec:d9:7a:18,10.252.0.161,ncn-m001,infinite # NMN
        host-record=ncn-m001,ncn-m001.nmn,10.252.0.161
        host-record=kubeapi-vip,kubeapi-vip.nmn,10.252.0.151 # k8s-virtual-ip
        host-record=rgw-vip,rgw-vip.nmn,10.252.0.152 # rgw-virtual-ip
        ```

        For example, the last NMN IP in statics.conf is 10.252.0.161.   Therefore, the dhcp-range in NMN.conf should start AFTER 10.252.0.161.

        ```bash
        dhcp-range=interface:vlan002,10.252.0.165,10.252.0.190,10m
        ```

    - [CASMINST-347](https://connect.us.cray.com/jira/browse/CASMINST-347)

        - For HMN.conf, make sure the range specified in the `domain` line INCLUDES the ncn-XXXX-mgmt IPs that are fixed in statics.conf.

        ```bash
        pit:~ /etc/dnsmasq.d # grep mgmt statics.conf
        dhcp-host=94:40:c9:37:67:72,10.254.1.5,ncn-s003-mgmt,infinite #HMN
        dhcp-host=94:40:c9:37:77:da,10.254.1.7,ncn-s002-mgmt,infinite #HMN
        dhcp-host=94:40:c9:37:77:14,10.254.1.9,ncn-s001-mgmt,infinite #HMN
        dhcp-host=94:40:c9:37:f3:90,10.254.1.11,ncn-w003-mgmt,infinite #HMN
        dhcp-host=94:40:c9:37:77:6a,10.254.1.13,ncn-w002-mgmt,infinite #HMN
        dhcp-host=94:40:c9:41:27:36,10.254.1.15,ncn-w001-mgmt,infinite #HMN
        dhcp-host=94:40:c9:37:67:46,10.254.1.17,ncn-m003-mgmt,infinite #HMN
        dhcp-host=94:40:c9:37:67:36,10.254.1.19,ncn-m002-mgmt,infinite #HMN
        dhcp-host=00:00:00:00:00:00,10.254.1.21,ncn-m001-mgmt,infinite #HMN
        ```

        ```bash
        domain=hmn,10.254.1.5,10.254.1.62,local
        ```

3. Modify the `FIXME` entries in `data.json` to align to your system.

    ```
    # STOP!
    # Edit, adjust all the ~FIXMES
    vim $crayname/data.json
    ```

    - `k8s-virtual-ip` and `rgw-virtual-ip`

        If you are installing a system that was previously 1.3, you can get these values from networks.yml for your system:  `https://stash.us.cray.com/projects/DST/repos/shasta_system_configs/browse/${system_name}/networks.yml`

        ```bash
        grep rgw_virtual_ip networks.yml
        grep k8s_virtual_ip networks.yml
        ```

    - `first-master-hostname`

        Set this to ncn-m002 since ncn-m001 will be used for the LiveCD.

    - `dns-server`

        Set this to the IP used for `nmn_cidr` in qnd-1.4.sh.  Do NOT include the /netmask.  This should be the IP only.  This will be the IP of the LiveCD where dnsmasq will be running.

    - `can-gw`

        Set this to the IP virtual gateway for vlan 7 on the spine switches.

    -  `ntp_local_nets`

        Leave this as the provided defaults `10.252.0.0/17,10.254.0.0/17`.   Just remove the `~FIXME~`.

    -  `ntp_peers`

        Enumerate all of the NCNs in the cluster.  In most cases, you can leave this as the default.

    -  `upstream_ntp_server`

        Set this to `cfntp-4-1.us.cray.com`

4. Validate `data.json` to sanitize any human-error:

    ```bash
    cat ${system_name}/data.json | jq
    ```

    If you do not see an error message, the format is valid.

5. Copy these files to the mounted data partition:

    ```bash
    cp -r ${system_name} /mnt/prep/
    cp ${system_name}/data.json /mnt/configs
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
linux:~ # ls -lR /mnt/data/
```

Now, unmount the bootable USB.

```bash
linux:~ # umount /mnt
```

## Manual Step 7 : Boot into your LiveCD.

Now you can boot into your LiveCD [LiveCD Startup](003-LIVECD-STARTUP.md)
