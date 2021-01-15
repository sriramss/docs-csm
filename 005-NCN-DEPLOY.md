# NCN Deployment

Before starting this you are expected to have networking and services setup.
If you are unsure, see the bottom of [LiveCD Install and Config](004-LIVECD-INSTALL-AND-CONFIG.md).

## Overview:

> NOTE: These steps will be automated. CASM/MTL is automating this process  with the cray-site-init (`csi`) tool.

1. [Warm-up / Pre-flight Checks](#warm-up--pre-flight-checks)
2. [Ensure artifacts are in place](#manual-step-1-ensure-artifacts-are-in-place)
3. [Add Certificate Authority](#manual-step-2-add-ca-to-cloud-init-metadata-server)
4. [Pre-NCN Boot Workarounds](#manual-step-3-apply-pre-ncn-boot-workarounds)
5. [Power Off NCNs and Set Boot Order](#manual-step-4-power-off-ncns-and-set-network-boot)
6. [Boot Storage Nodes](#manual-step-5-boot-storage-nodes)
7. [Check CEPH](#manual-check-1--stop--manually-inspect-storage)
8. [Boot Kubernetes Nodes](#manual-step-6-boot-kubernetes-managers-and-workers)
9. [Post-NCN Boot Workarounds](#manual-step-7-post-ncn-boot-work-arounds)
10. [Get Kubernetes Cluster Credentials](#manual-step-8-add-cluster-credentials-to-the-livecd)
11. [Check Kubernetes](#manual-check-2--stop--verify-quorum-and-expected-counts)

## Warm-up / Pre-flight Checks

> **Do not pass GO, do not collect $200.**

First, there are some important checks to be done before continuing. These serve to prevent mayhem during
installs and operation that are hard to debug. Please note, more checks may be added over time
 and existing checks may receive updates or become defunct.

#### Check : Switchport MTU

CSI will either run a test if it exists, or will provide the command to run by hand:
```bash
pit:~ # csi pit validate --mtu
```

Manually check the MTU of the spine ports connected to the NCNs is set to 9216. Check this on all spines that the
first nine NCNs are using (minimum is two).

  ```bash
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

Typically, we should have eight leases for NCN BMCs. Some systems may have less, but the
recommended minimum is 3 of each type (k8s-managers, k8s-workers, ceph-storage).

#### Check : Controller Leases

CSI will either run a test if it exists, or will provide the command to run by hand.
```bash
pit:~ # csi pit validate --dns-dhcp
```

To run the test by hand if CSI is unavailable or has doubt:

1. Check for NCN lease count:

    ```bash
    grep -Eo ncn-.*-mgmt /var/lib/misc/dnsmasq.leases | wc -l
    8
    ```

    `8` is the number we're expecting typically, since NCN "number 9" is the node
    currently booted up with the LiveCD (the node you're standing on).

2. Print off each NCN we'll target for booting.

    ```bash
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

#### Optional : Safeguards

These safeguards should be disregarded for fresh-(re)installs and baremetal deploys. Skip to the first step:  [Manual Step 1](#manual-step-1--ensure-artifacts-are-in-place)

**If you are upgrading** you should run through these safe-guards on a by-case basis:
1. Whether or not CEPH should be preserved.
2. Whether or not the RAIDs should be protected.

##### Safeguard: CEPH OSDs

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
pit:~ # sed -i 's/wipe-ceph-osds": "yes"/wipe-ceph-osds": "no"/g' /var/www/ephemeral/configs/data.json

# set wipe-ceph-osds=yes
pit:~ # sed -i 's/wipe-ceph-osds": "no"/wipe-ceph-osds": "yes"/g' /var/www/ephemeral/configs/data.json
```

> NOTE: some earlier data.json files contain a typo of "wipe-ceph-**ods**": "yes", the typo is not
> honored, please correct it to `wipe-ceph-osd`


Verify setting:

```bash
pit:~ # grep wipe /var/www/ephemeral/configs/data.json | sort -u
        "wipe-ceph-osds": "yes"
```

Activate the new setting:

```bash
pit:~ # systemctl restart basecamp
```

##### Safeguard: RAIDS / BOOTLOADERS / SquashFS / OverlayFS

Edit `/var/www/boot/script.ipxe` and align the following options as you see them here:

- `rd.live.overlay.reset=0` will prevent any overlayFS files from being cleared.
- `metal.no-wipe=1` will guard against touching RAIDs, disks, and partitions.

# Deployment

Once warmup / pre-flight checks are done the following procedure can be started.

### Manual Step 1: Ensure artifacts are in place

Mount the USB stick's data partition, and setup links for booting.

This will select the first boot image in each of the ceph and k8s directories and link it in /var/www.

```bash
pit:~ # /root/bin/set-sqfs-links.sh
```

Make sure the correct images were selected.
```bash
pit:~ # ls -l /var/www
```

### Manual Step 2: Add CA to cloud-init Metadata Server

Platform Certificate Authority (CA) certificates must be added to Basecamp (cloud-init), so that NCN nodes can verify the certificates for components such as the ingress gateways.

> **Failure to perform this step will result in subsequent, often hard to diagnose and fix, problems.**

> **IMPORTANT - NOTE FOR `AIRGAP`** You must have already brought this with you from [002 LiveCD Setup](002-LIVECD-SETUP.md), or your Git server must be reachable. If it is not because this is a true-airgapped environment, then you must obtain and port this manifiest repository to your LiveCD and return to this step.

1. If you have not already done so, please clone the shasta-cfg repository for the system.

    ```bash
    pit:~ # export SYSTEM_NAME=sif
    pit:~ # git clone https://stash.us.cray.com/scm/shasta-cfg/${SYSTEM_NAME}.git /var/www/ephemeral/prep/site-init
    ```

2. Use `csi` to patch `data.json` using `customizations.yaml` and the sealed secret private key.

    This process is idempotent if the CAs have already been added.

    ```bash
    pit:~ # PREP=/var/www/ephemeral/prep/site-init
    pit:~ # csi patch ca --customizations-file $PREP/customizations.yaml --cloud-init-seed-file /var/www/ephemeral/configs/data.json --sealed-secret-key-file $PREP/certs/sealed_secrets.key
    2020/12/01 11:41:29 Backup of cloud-init seed data at /var/www/ephemeral/configs/data.json-1606844489
    2020/12/01 11:41:29 Patched cloud-init seed data in place
    ```

    > NOTE: If using a non-default Certificate Authority (sealed secret), you'll need to verify that the vault chart overrides are updated with the correct sealed secret name to inject and use the `--sealed-secret-name` parameter. See `csi patch ca --help` for usage.

3. Restart basecamp to force loading the new metadata.

    ```bash
    pit:~ # systemctl restart basecamp
    ```

### Manual Step 3: Apply "Pre-NCN Boot" Workarounds

Check for workarounds in the `/var/www/ephemeral/prep/csm-x.x.x/fix/before-ncn-boot` directory.  If there are any workarounds in that directory, run those now.   Instructions are in the README files.

```bash
# Example
pit:~ # ls /var/www/ephemeral/prep/csm-x.x.x/fix/before-ncn-boot
casminst-124
```

### Manual Step 4: Power Off NCNs and Set Network Boot

1. **IMPORTANT** all other NCNs (not including the one your liveCD will be on) must be powered **off**. If you still have access to the BMC IPs, you can use `ipmitool` to confirm power state:

    ```bash
    for i in m002 m003 w001 w002 w003 s001 s002 s003;do ipmitool -I lanplus -U $username -P $password -H ncn-${i}-mgmt chassis power status;done
    ```

2. Set each node to always UEFI Network Boot

    ```bash
    username=bob
    password=alice

    # ALWAYS PXE BOOT; sets a system to PXE
    ipmitool -I lanplus -U $username -P $password -H ncn-s003-mgmt chassis bootdev pxe options=efiboot,persistent
    ipmitool -I lanplus -U $username -P $password -H ncn-s002-mgmt chassis bootdev pxe options=efiboot,persistent
    ipmitool -I lanplus -U $username -P $password -H ncn-s001-mgmt chassis bootdev pxe options=efiboot,persistent
    ipmitool -I lanplus -U $username -P $password -H ncn-w003-mgmt chassis bootdev pxe options=efiboot,persistent
    ipmitool -I lanplus -U $username -P $password -H ncn-w002-mgmt chassis bootdev pxe options=efiboot,persistent
    ipmitool -I lanplus -U $username -P $password -H ncn-w001-mgmt chassis bootdev pxe options=efiboot,persistent
    ipmitool -I lanplus -U $username -P $password -H ncn-m003-mgmt chassis bootdev pxe options=efiboot,persistent
    ipmitool -I lanplus -U $username -P $password -H ncn-m002-mgmt chassis bootdev pxe options=efiboot,persistent

    # for installs still using w001 for the liveCD:
    ipmitool -I lanplus -U $username -P $password -H ncn-m001-mgmt chassis bootdev pxe options=efiboot,persistent
    ```

The NCNs are now primed, ready for booting.

> Note: some BMCs will "flake" and not adhear to these `ipmitool chassi bootdev` options. As a fallback, cloud-init will
> correct the bootorder after NCNs complete their first boot. The boot order is defined in [101 NCN Booting](101-NCN-BOOTING.md).


### Manual Step 5: Boot Storage Nodes

This will again just `echo` the commands.  Look them over and validate they are ok before running them.  This just `grep`s out the storage nodes so you only get the workers and managers.

Get our boot commands:
```bash
username=''
password=''
for bmc in $(grep -Eo ncn-.*-mgmt /var/lib/misc/dnsmasq.leases | grep s | sort); do
    echo ipmitool -I lanplus -U $username -P $password -H $bmc chassis bootdev pxe options=efiboot
    echo "ipmitool -I lanplus -U $username -P $password -H $bmc chassis power off"
    echo "sleep 5"
    echo "ipmitool -I lanplus -U $username -P $password -H $bmc chassis power status"
    echo "ipmitool -I lanplus -U $username -P $password -H $bmc chassis power on"
    echo ""
done
```

Watch consoles with the Serial-over-LAN, or use conman if you've setup `/etc/conman.conf` with
the static IPs for the BMCs.

```bash
# Connect to ncn-s001..
username=''
password=''
bmc='ncn-s002-mgmt'
pit:~ # echo ipmitool -I lanplus -U $username -P $password -H $bmc sol activate

# ..or print available consoles:
pit:~ # conman -q
pit:~ # conman -j ncn-s001
```

Once you see your first 3 storage nodes boot, you should start seeing the CEPH installer running
on the first storage nodes console. After 4-5 minutes, CEPH should be deployed.

### Manual Check 1 :: STOP :: Manually Inspect Storage

Run this to get validtion commands for ceph.
```bash
pit:~ # csi pit validate --ceph
```

The gist of it is to run `ceph -s` and verify cluster is healthy from `ncn-s001.nmn`.  Verify that health is `HEALTH_OK, and that we have mon, mgr, mds, osd and rgw services in the output:

```bash
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

### Manual Step 6: Boot Kubernetes Managers and Workers

Look them over and validate they are ok before running them. This snippet `grep`s out the storage nodes so you only get the workers and managers.

```bash
username=''
password=''
for bmc in $(grep -Eo ncn-.*-mgmt /var/lib/misc/dnsmasq.leases | grep -v s | sort); do
    echo ipmitool -I lanplus -U $username -P $password -H $bmc chassis bootdev pxe options=efiboot
    echo "ipmitool -I lanplus -U $username -P $password -H $bmc chassis power off"
    echo "sleep 5"
    echo "ipmitool -I lanplus -U $username -P $password -H $bmc chassis power status"
    echo "ipmitool -I lanplus -U $username -P $password -H $bmc chassis power on"
    echo ""
done
```

> **NOTE FOR `HPE Systems`:** Some systems hang at system POST with the following messages on the console, if you hang here for more than five minutes, power the node off and back on again. If this is the case, you can wait or
> attempt a reboot. A short-term fix for this is in [304 NCN PCIe Netboot and Recable](304-NCN-PCIE-NETBOOT-AND-RECABLE.md) which disables SR-IOV on Mellanox cards.

```bash
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

### Manual Step 7: Post NCN Boot Work-arounds

Before we move onto checking anything about the nodes, we need to go over work-arounds.

##### CASMINST-778

cloud-init hits a race-condition and does not retrieve any metadata when it queries during boot. This results
in several side-effects, such as a lack of hostname (the vanilla, `ncn` hostname is present), and lack of ceph or k8s cluster join. Basically no cloud-init function runs.

*Diagnosis:* If you have a hostname of `ncn` and this returns metadata then you have this bug:
```bash
ncn:~ # curl http://pit:8888/meta-data
```
If it says no data found, then you may have a misalignment in your `ncn_metadata.csv` file instead of this bug.

*Fix*: Run the work-around in CSM work-arounds.

### Manual Step 8: Add Cluster Credentials to the LiveCD

After 5-10 minutes, the first master should be provisioning other nodes in the cluster. At this time, credentials can be
obtained.

Copy the Kubernetes config to the LiveCD to be able to use `kubectl` as cluster administrator.
> This will always be whatever node is the `first-master-hostname` in your `/var/www/ephemeral/configs/data.json | jq` file. Often if you are provisioning your CRAY from `ncn-m001` then you can expect to fetch these from `ncn-m002`.

```bash
pit:~ # mkdir ~/.kube
pit:~ # scp ncn-m002.nmn:/etc/kubernetes/admin.conf ~/.kube/config
```
Now you can run `kubectl get nodes` to see the nodes in the cluster.

### Manual Check 2 :: STOP :: Verify Quorum and Expected Counts

1. Verify all nodes have joined the cluster
    > You can also run this fromm any k8s-manager/k8s-worker node
    ```bash
    pit:~ # kubectl get nodes -o wide
    NAME       STATUS   ROLES    AGE    VERSION   INTERNAL-IP   EXTERNAL-IP   OS-IMAGE                                                  KERNEL-VERSION         CONTAINER-RUNTIME
    ncn-m002   Ready    master   128m   v1.18.6   10.252.1.14   <none>        SUSE Linux Enterprise High Performance Computing 15 SP2   5.3.18-24.37-default   containerd://1.3.4
    ncn-m003   Ready    master   127m   v1.18.6   10.252.1.13   <none>        SUSE Linux Enterprise High Performance Computing 15 SP2   5.3.18-24.37-default   containerd://1.3.4
    ncn-w001   Ready    <none>   90m    v1.18.6   10.252.1.12   <none>        SUSE Linux Enterprise High Performance Computing 15 SP2   5.3.18-24.37-default   containerd://1.3.4
    ncn-w002   Ready    <none>   88m    v1.18.6   10.252.1.11   <none>        SUSE Linux Enterprise High Performance Computing 15 SP2   5.3.18-24.37-default   containerd://1.3.4
    ncn-w003   Ready    <none>   82m    v1.18.6   10.252.1.10   <none>        SUSE Linux Enterprise High Performance Computing 15 SP2   5.3.18-24.37-default   containerd://1.3.4
    ```

2. Verify 3 storage config maps have been created
    > Run on `ncn-s001.nmn`
    ```bash
    ncn-s001:~ # kubectl get cm | grep csi-sc
    cephfs-csi-sc                    1      8d
    kube-csi-sc                      1      8d
    sma-csi-sc                       1      8d
    ```

3. Verify that all the pods in the kube-system namespace are running.  Make sure all pods except coredns have an IP starting with 10.252.
    ```bash
    ncn-m002:~ # kubectl get po -n kube-system
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

### Next: Run Loftsman Platform Deployments

Move onto Installing platform services [NCN Platform Install](006-NCN-PLATFORM-INSTALL.md).


### Manual Step 8: Update BGP peers on switches.

After the NCNs are booted the BGP peers will need to be checked and updated if the neighbors IPs are incorrect on the switches.  
See the doc to [Update BGP Neighbors](400-SWITCH-BGP-NEIGHBORS.md).