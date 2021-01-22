# NCN Deployment

Before starting this you are expected to have networking and services setup.
If you are unsure, see the bottom of [LiveCD Install and Config](004-LIVECD-INSTALL-AND-CONFIG.md).

## Overview:

> NOTE: These steps will be automated. CASM/MTL is automating this process  with the cray-site-init (`csi`) tool.

**Checks**

- [Warm-up / Pre-flight Checks](#warm-up--pre-flight-checks)
- [Check switchport MTU](#check-switchport-mtu)
- [Check controller leases](#check-controller-leases)
- [Optional safeguards](#optional-safeguards)
- [Safeguards Ceph OSDs](#safeguard-ceph-osds)
- [Safeguard RAIDS / BOOTLOADERS / SquashFS / OverlayFS](#safeguard-raids-bootloaders-squashfs-overlayfs)

**Deployment**

- [Ensure artifacts are in place](#ensure-artifacts-are-in-place)
- [Add Certificate Authority](#add-ca-to-cloud-init-metadata-server)
- [Pre-NCN Boot Workarounds](#apply-pre-ncn-boot-workarounds)
- [Wipe nodes, if needed](#wipe-nodes-if-needed)
- [Power Off NCNs and Set Boot Order](#power-off-ncns-and-set-network-boot)
- [Boot Storage Nodes](#boot-storage-nodes)
- [Check CEPH](#manually-inspect-storage)
- [Boot Kubernetes Nodes](#boot-kubernetes-managers-and-workers)
- [Post-NCN Boot Workarounds](#post-ncn-boot-work-arounds)
- [Get Kubernetes Cluster Credentials](#add-cluster-credentials-to-the-livecd)
- [Check Kubernetes](#verify-quorum-and-expected-counts)
- [Update BGP Peers](#manual-step-9-update-bgp-peers-on-switches)
- [Change root password](#change-root-password)
- [Run Loftsman Platform Deployments](#run-loftsman-platform-deployments)

## Warm-up / Pre-flight Checks

First, there are some important checks to be done before continuing. These serve to prevent mayhem during installation and operation that are hard to debug.   Please note, more checks may be added over time  and existing checks may receive updates or become defunct.

> Many of these use the `pit validate` command, which simply runs some shell commands for you, but it's up to you to determine what the output means.  This will no longer be the case one the GOSS tests are plugged into the `pit validate` command.

#### Check Switchport MTU

```
pit:~ # csi pit validate --mtu
```

_Manually_ check the MTU of the spine ports connected to the NCNs is set to `9216`. Check this on all spines that the NCNs are using (minimum is two).

```
sw-spine01 [standalone: master] # show interface status | include ^Mpo
Mpo1                  Up                    Enabled                                           9216              -
Mpo2                  Up                    Enabled                                           9216              -
Mpo3                  Up                    Enabled                                           9216              -
Mpo4                  Up                    Enabled                                           9216              -
Mpo5                  Up                    Enabled                                           9216              -
Mpo6                  Up                    Enabled                                           9216              -
Mpo7                  Up                    Enabled                                           9216              -
Mpo8                  Up                    Enabled                                           9216              -
Mpo9                  Up                    Enabled                                           9216              -
Mpo11                 Down                  Enabled                                           9216              -
Mpo12                 Down                  Enabled                                           9216              -
Mpo15                 Down                  Enabled                                           9216              sw-leaf01-mlag
Mpo114                Down                  Enabled                                           9216              -
Mpo115                Up                    Enabled                                           9216              -
```

#### Check Controller Leases

There should be a lease for each NCN in your system (with the exception of the livecd itself).

```
pit:~ # csi pit validate --dns-dhcp
```

To run the test by hand if CSI is unavailable or has doubt:

1. Check that there are leases for your BMCs

```bash
grep -Eo ncn-.*-mgmt /var/lib/misc/dnsmasq.leases
```

```
pit:~ # grep -Eo ncn-.*-mgmt /var/lib/misc/dnsmasq.leases | sort
ncn-m002-mgmt
ncn-m003-mgmt
ncn-w001-mgmt
ncn-w002-mgmt
ncn-w003-mgmt
ncn-s001-mgmt
ncn-s002-mgmt
ncn-s003-mgmt
```

#### Optional Safeguards

**If you are upgrading** you should run through these safe-guards on a by-case basis:

1. Whether or not CEPH should be preserved.
2. Whether or not the RAIDs should be protected.

##### Safeguard CEPH OSDs

Edit `/var/www/ephemeral/configs/data.json` and align the following options:

```json
{
  ..
  // Disables ceph wipe:
  "wipe-ceph-osds": "no"
  ..
}
```
```json
{
  ..
  // Restores default behavior:
  "wipe-ceph-osds": "yes"
  ..
}
```

Quickly toggle yes or no to the file:

```bash
# set wipe-ceph-osds=no
sed -i 's/wipe-ceph-osds": "yes"/wipe-ceph-osds": "no"/g' /var/www/ephemeral/configs/data.json

# set wipe-ceph-osds=yes
sed -i 's/wipe-ceph-osds": "no"/wipe-ceph-osds": "yes"/g' /var/www/ephemeral/configs/data.json
```

Activate the new setting:

```
pit:~ # systemctl restart basecamp
```

##### Safeguard RAIDS / BOOTLOADERS / SquashFS / OverlayFS

Edit `/var/www/boot/script.ipxe` and align the following options as you see them here:

- `rd.live.overlay.reset=0` will prevent any overlayFS files from being cleared.
- `metal.no-wipe=1` will guard against touching RAIDs, disks, and partitions.

# Deployment

Once warmup / pre-flight checks are done the following procedure can be started.

## Ensure artifacts are in place

This will create folders for each host in `/var/www`, allowing each host to have their own unique kernel, initrd, and squashfs image (KIS).

```
pit:~ # /root/bin/set-sqfs-links.sh
```

Make sure there is a folder for each NCN and it has KIS artifacts in each directory.

```
pit:~ # ls -R /var/www/ncn*
/var/www/ncn-m002:
filesystem.squashfs  initrd.img.xz  kernel

/var/www/ncn-m003:
filesystem.squashfs  initrd.img.xz  kernel

/var/www/ncn-s001:
filesystem.squashfs  initrd.img.xz  kernel

/var/www/ncn-s002:
filesystem.squashfs  initrd.img.xz  kernel

/var/www/ncn-s003:
filesystem.squashfs  initrd.img.xz  kernel

/var/www/ncn-w001:
filesystem.squashfs  initrd.img.xz  kernel

/var/www/ncn-w002:
filesystem.squashfs  initrd.img.xz  kernel

/var/www/ncn-w003:
filesystem.squashfs  initrd.img.xz  kernel
```

## Add CA to cloud-init Metadata Server

Platform Certificate Authority (CA) certificates must be added to Basecamp (cloud-init), so that NCN nodes can verify the certificates for components such as the ingress gateways.

> **Failure to perform this step will result in subsequent, often hard to diagnose and fix, problems.**

> **IMPORTANT - NOTE FOR `AIRGAP`** You must have already brought this with you from [002 LiveCD Setup](002-LIVECD-SETUP.md), or your Git server must be reachable. If it is not because this is a true-airgapped environment, then you must obtain and port this manifiest repository to your LiveCD and return to this step.

1. If you have not already done so, please clone the shasta-cfg repository for the system.

```
pit:~ # git clone https://stash.us.cray.com/scm/shasta-cfg/eniac.git /var/www/ephemeral/prep/site-init
```

2. Use `csi` to patch `data.json` using `customizations.yaml` and the sealed secret private key.

> This process is idempotent if the CAs have already been added.

```
pit:~ # PREP=/var/www/ephemeral/prep/site-init
pit:~ # csi patch ca --customizations-file $PREP/customizations.yaml --cloud-init-seed-file /var/www/ephemeral/configs/data.json --sealed-secret-key-file $PREP/certs/sealed_secrets.key
2020/12/01 11:41:29 Backup of cloud-init seed data at /var/www/ephemeral/configs/data.json-1606844489
2020/12/01 11:41:29 Patched cloud-init seed data in place
```

> NOTE: If using a non-default Certificate Authority (sealed secret), you'll need to verify that the vault chart overrides are updated with the correct sealed secret name to inject and use the `--sealed-secret-name` parameter. See `csi patch ca --help` for usage.

3. Restart basecamp to force loading the new metadata.

```
pit:~ # systemctl restart basecamp
```

### Apply "Pre-NCN Boot" Workarounds

Check for workarounds in the `/var/www/ephemeral/prep/csm-x.x.x/fix/before-ncn-boot` directory.  If there are any workarounds in that directory, run those now.   Instructions are in the `README` files.

```
# Example
pit:~ # ls /var/www/ephemeral/prep/csm-x.x.x/fix/before-ncn-boot
casminst-124
```

### Wipe nodes, if needed

**If you're doing a reinstall, you'll need to wipe the machines first**

> If you have more than 9 NCNs, you should add those hostnames into the `for` loops below.

```bash
for i in m002 m003 w001 w002 w003 s001 s002 s003;do ssh ncn-$i "wipefs --all --force /dev/sd* /dev/disk/by-label/*";done
```

### Power Off NCNs and Set Network Boot

1. **IMPORTANT** all other NCNs (not including the one your liveCD will be on) must be powered **off**. If you still have access to the BMC IPs, you can use `ipmitool` to confirm power state:

> If you have more than 9 NCNs, you should add those hostnames into the `for` loops below.

```bash
for i in m002 m003 w001 w002 w003 s001 s002 s003;do ipmitool -I lanplus -U username -P password -H ncn-${i}-mgmt chassis power status;done
for i in m002 m003 w001 w002 w003 s001 s002 s003;do ipmitool -I lanplus -U username -P password -H ncn-${i}-mgmt chassis power off;done
```

2. Set each node to always UEFI Network Boot

```bash
# ALWAYS PXE BOOT; sets a system to PXE
for i in m002 m003 w001 w002 w003 s001 s002 s003;do ipmitool -I lanplus -U username -P password -H ncn-${i}-mgmt chassis bootdev pxe options=efiboot,persistent;done
```

The NCNs are now primed, ready for booting.

> Note: some BMCs will "flake" and not adhear to these `ipmitool chassi bootdev` options. As a fallback, cloud-init will
> correct the bootorder after NCNs complete their first boot. The boot order is defined in [101 NCN Booting](101-NCN-BOOTING.md).

**Important Note**
```bash
Our recommended boot order for the ncn management plane is as follows
  1. storage
  2. managers
  3. workers

Please keep in mind the timing of the ceph installation is dependent on the number of storage nodes.
You can opt to use this boot stratedgy.
  1. storage then wait 1-2 minutes
  2. boot managers then wait 1-2 minutes
  3. boot workers.

There is code in place to handle waiting for the different node types to come online so additional configuration step can be completed.
```

### Boot Storage Nodes

```bash
# Boot just the storage nodes
for i in s001 s002 s003;do ipmitool -I lanplus -U username -P password -H ncn-${i}-mgmt chassis power on;done
```

Watch consoles with the Serial-over-LAN, or use conman if you've setup `/etc/conman.conf` with the static IPs for the BMCs.

```bash
# Connect to ncn-s001..
echo ipmitool -I lanplus -U username -P password -H ncn-s001-mgmt sol activate

# ..or print available consoles:
conman -q
conman -j ncn-s001-mgmt

# ..or tail multiple log files
tail -f /var/log/conman/ncn-s*
```

Once you see your first 3 storage nodes boot, you should start seeing the CEPH installer running
on the first storage nodes console. Optionally, you can also tail -f /var/log/cloud-init-ouput.log.
**Remember, the ceph installation time is dependent on the number of storage nodes**

You can start booting the manager and worker nodes during the ceph installation.  

### Manual Check 1 :: STOP :: Manually Inspect Storage
**This is optional at this point since a very large cluster will take longer to install.  We also have a similar check in the install so watching the logs should suffice.**

Run this to get validation commands for ceph.
```bash
csi pit validate --ceph
```

The gist of it is to run `ceph -s` and verify cluster is healthy from `ncn-s001.nmn`.  Verify that health is `HEALTH_OK`, and that we have `mon`, `mgr`, `mds`, `osd` and `rgw` services in the output:

```
ncn-s001:~ # ceph -s
  cluster:
    id:     99ffa799-1209-49d4-9889-c7c3056e2062
    health: HEALTH_OK

  services:
    mon: 3 daemons, quorum ncn-s001,ncn-s002,ncn-s003 (age 13m)
    mgr: ncn-s001(active, since 5m), standbys: ncn-s003, ncn-s002
    mds: cephfs:1 {0=ncn-s002=up:active} 2 up:standby
    osd: 18 osds: 18 up (since 10m), 18 in (since 10m)
    rgw: 3 daemons active (ncn-s001.rgw0, ncn-s002.rgw0, ncn-s003.rgw0)

  task status:
    scrub status:
        mds.ncn-s002: idle

  data:
    pools:   10 pools, 968 pgs
    objects: 342 objects, 26 KiB
    usage:   18 GiB used, 24 TiB / 24 TiB avail
    pgs:     968 active+clean
```

### Boot Kubernetes Managers and Workers

```bash
for i in m002 m003 w001 w002 w003;do ipmitool -I lanplus -U username -P password -H ncn-${i}-mgmt chassis power on;done
```

> **NOTE FOR `HPE Systems`:** Some systems hang at system POST with the following messages on the console, if you hang here for more than five minutes, power the node off and back on again. If this is the case, you can wait or attempt a reboot. A short-term fix for this is in [304 NCN PCIe Netboot and Recable](304-NCN-PCIE-NETBOOT-AND-RECABLE.md) which disables SR-IOV on Mellanox cards.

```
RAS]No Valid Oem Memory Map Table Found
[RAS]Set Error Type With Address structure locate: 0x0000000077EEAD98
 33%: BIOS Configuration Initialization
RbsuSetupDxeEntry, failed to initial product lines feature: Unsupported
Create243Record: Error finding ME Type 216 record.
HpSmbiosType243AbsorokaFwInformationEntryPoint: SmbiosSystemOptionString failed! Status = Not Found
CheckDebugCertificateStatus: unpack error.
 41%: Early PCI Initialization - Start
CreatePciIoDevice: The SR-IOV card[0x00000000|0x86|0x00|0x00] has invalid setting on InitialVFs register
CreatePciIoDevice: its SR-IOV function will be disabled. We need to report the issue to card vandor
CreatePciIoDevice: The SR-IOV card[0x00000000|0x86|0x00|0x00] has invalid setting on InitialVFs register
CreatePciIoDevice: its SR-IOV function will be disabled. We need to report the issue to card vandor
CreatePciIoDevice: The SR-IOV card[0x00000000|0x03|0x00|0x00] has invalid setting on InitialVFs register
CreatePciIoDevice: its SR-IOV function will be disabled. We need to report the issue to card vandor
CreatePciIoDevice: The SR-IOV card[0x00000000|0x03|0x00|0x00] has invalid setting on InitialVFs register
CreatePciIoDevice: its SR-IOV function will be disabled. We need to report the issue to card vandor
CreatePciIoDevice: The SR-IOV card[0x00000000|0x86|0x00|0x00] has invalid setting on InitialVFs register
CreatePciIoDevice: its SR-IOV function will be disabled. We need to report the issue to card vandor
CreatePciIoDevice: The SR-IOV card[0x00000000|0x03|0x00|0x00] has invalid setting on InitialVFs register
CreatePciIoDevice: its SR-IOV function will be disabled. We need to report the issue to card vandor
```

### Post NCN Boot Work-arounds

Check for workarounds in the `/var/www/ephemeral/prep/csm-x.x.x/fix/after-ncn-boot` directory.  If there are any workarounds in that directory, run those now.   Instructions are in the `README` files.

```
# Example
pit:~ # ls /var/www/ephemeral/prep/csm-x.x.x/fix/after-ncn-boot
casminst-12345
```

### Add Cluster Credentials to the LiveCD

After 5-10 minutes, the first master should be provisioning other nodes in the cluster. At this time, credentials can be obtained.

Copy the Kubernetes config to the LiveCD to be able to use `kubectl` as cluster administrator.

> This will always be whatever node is the `first-master-hostname` in your `/var/www/ephemeral/configs/data.json | jq` file. If you are provisioning your CRAY from `ncn-m001` then you can expect to fetch these from `ncn-m002`.

```
pit:~ # mkdir ~/.kube
pit:~ # scp ncn-m002.nmn:/etc/kubernetes/admin.conf ~/.kube/config
```

### Verify Quorum and Expected Counts

1. Verify all nodes have joined the cluster

> You can also run this from any k8s-manager/k8s-worker node

```
pit:~ # kubectl get nodes -o wide
NAME       STATUS   ROLES    AGE    VERSION   INTERNAL-IP   EXTERNAL-IP   OS-IMAGE                                                  KERNEL-VERSION         CONTAINER-RUNTIME
ncn-m002   Ready    master   128m   v1.18.6   10.252.1.14   <none>        SUSE Linux Enterprise High Performance Computing 15 SP2   5.3.18-24.37-default   containerd://1.3.4
ncn-m003   Ready    master   127m   v1.18.6   10.252.1.13   <none>        SUSE Linux Enterprise High Performance Computing 15 SP2   5.3.18-24.37-default   containerd://1.3.4
ncn-w001   Ready    <none>   90m    v1.18.6   10.252.1.12   <none>        SUSE Linux Enterprise High Performance Computing 15 SP2   5.3.18-24.37-default   containerd://1.3.4
ncn-w002   Ready    <none>   88m    v1.18.6   10.252.1.11   <none>        SUSE Linux Enterprise High Performance Computing 15 SP2   5.3.18-24.37-default   containerd://1.3.4
ncn-w003   Ready    <none>   82m    v1.18.6   10.252.1.10   <none>        SUSE Linux Enterprise High Performance Computing 15 SP2   5.3.18-24.37-default   containerd://1.3.4
```

2. Verify 3 storage config maps have been created

```
pit:~ # kubectl get -A cm | grep csi-sc
cephfs-csi-sc                    1      8d
kube-csi-sc                      1      8d
sma-csi-sc                       1      8d
```

3. Verify that all the pods in the kube-system namespace are running.  Make sure all pods except coredns have an IP starting with 10.252.

```
ncn-m002:~ # kubectl get po -o wide -n kube-system
NAME                               READY   STATUS    RESTARTS   AGE	IP            NODE       NOMINATED NODE   READINESS GATES
coredns-66bff467f8-7psjb           1/1     Running   0          8m12s	10.36.0.44    ncn-w001   <none>           <none>
coredns-66bff467f8-hhw8f           1/1     Running   0          8m12s	10.44.0.3     ncn-m003   <none>           <none>
etcd-ncn-m002                      1/1     Running   0          7m25s	10.252.1.14   ncn-m002   <none>           <none>
etcd-ncn-m003                      1/1     Running   0          2m34s	10.252.1.13   ncn-m003   <none>           <none>
kube-apiserver-ncn-m002            1/1     Running   0          7m5s	10.252.1.14   ncn-m002   <none>           <none>
kube-apiserver-ncn-m003            1/1     Running   0          2m21s	10.252.1.13   ncn-m003   <none>           <none>
kube-controller-manager-ncn-m002   1/1     Running   0          7m5s	10.252.1.14   ncn-m002   <none>           <none>
kube-controller-manager-ncn-m003   1/1     Running   0          2m21s	10.252.1.13   ncn-m003   <none>           <none>
kube-multus-ds-amd64-7cnxz         1/1     Running   0          2m39s	10.252.1.14   ncn-m002   <none>           <none>
kube-multus-ds-amd64-8vdld         1/1     Running   0          2m35s	10.252.1.12   ncn-w001   <none>           <none>
kube-multus-ds-amd64-dxxvj         1/1     Running   1          7m30s	10.252.1.13   ncn-m003   <none>           <none>
kube-multus-ds-amd64-dxxvj         1/1     Running   1          7m30s	10.252.1.11   ncn-w002   <none>           <none>
kube-multus-ds-amd64-ps5zp         1/1     Running   0          8m12s	10.252.1.10   ncn-w003   <none>           <none>
kube-proxy-lr6z9                   1/1     Running   0          2m35s 	10.252.1.11   ncn-w002   <none>           <none>
kube-proxy-pmv8l                   1/1     Running   0          7m30s	10.252.1.10   ncn-w003   <none>           <none>
kube-proxy-s7jsl                   1/1     Running   0          2m39s	10.252.1.14   ncn-m002   <none>           <none>
kube-proxy-z9r2m                   1/1     Running   0          8m12s	10.252.1.13   ncn-m003   <none>           <none>
kube-proxy-z4tkt                   1/1     Running   0          8m12s	10.252.1.12   ncn-w001   <none>           <none>
kube-scheduler-ncn-m002            1/1     Running   0          7m4s	10.252.1.14   ncn-m002   <none>           <none>
kube-scheduler-ncn-m003            1/1     Running   0          2m20s	10.252.1.13   ncn-m003   <none>           <none>
weave-net-bf8qn                    2/2     Running   0          7m55s	10.252.1.10   ncn-w003   <none>           <none>
weave-net-hsczs                    2/2     Running   4          7m30s	10.252.1.13   ncn-m003   <none>           <none>
weave-net-schwt                    2/2     Running   0          2m39s	10.252.1.12   ncn-w001   <none>           <none>
weave-net-vwqbt                    2/2     Running   0          2m35s	10.252.1.14   ncn-m002   <none>           <none>
weave-net-zm5t4                    2/2     Running   0          2m35s	10.252.1.11   ncn-w002   <none>           <none>
```

### Manual Step 9: Update BGP peers on switches.

After the NCNs are booted the BGP peers will need to be checked and updated if the neighbors IPs are incorrect on the switches. At this point the BGP peering sessions on the switches will not be established.  See the doc to [Update BGP Neighbors](400-SWITCH-BGP-NEIGHBORS.md).

### Change root password

[Change the default root password on all NCNs](056-NCN-RESET-PASSWORDS.md)

### Run Loftsman Platform Deployments

Move onto Installing platform services [NCN Platform Install](006-NCN-PLATFORM-INSTALL.md).
