# NCN Deployment

Before starting this you are expected to have networking and services setup.
If you are unsure, see the bottom of [LiveCD Install and Config](004-LIVECD-INSTALL-AND-CONFIG.md).

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
#### Check : Update basecamp data to include Certificate Authority (CA) certificates

> **IMPORTANT** You must have a ```shasta-cfg``` git repo created and sync'd from ```stable``` (or a conscious deviation) to perform this step. Given the ```shasta-cfg``` model *may* be in flux, contact SSI if you need a new repo created. They can also provide you with a process to synchronize from ```stable```.

Basecamp needs the right data to setup the certificates, if you already set this up please move onto the next check/step.

> **IMPORTANT** Failure to validate/pass this check will entail request failure acorss all/core ingress gateways leading to ceph RGW failure (s3).

1. Clone the respective shasta-cfg repository.

    ```bash
    pit:~ # cd /tmp/
    pit:/tmp # mkdir --mode=750 shasta-cfg
    pit:/tmp # cd shasta-cfg/
    pit:/tmp/shasta-cfg # git clone https://stash.us.cray.com/scm/shasta-cfg/surtur.git
    Cloning into 'surtur'...
    remote: Counting objects: 88, done.
    remote: Compressing objects: 100% (87/87), done.
    remote: Total 88 (delta 18), reused 0 (delta 0)
    Unpacking objects: 100% (88/88), 34.24 MiB | 4.94 MiB/s, done.
    ```

2. Use `csi` to patch `data.json` using `customizations.yaml` and the private sealed secret key.

    ```bash
    surtur-ncn-m001-pit:/tmp/shasta-cfg # csi patch ca --customizations-file ./surtur/customizations.yaml --cloud-init-seed-file /var/www/ephemeral/configs/data.json --sealed-secret-key-file ./surtur/certs/sealed_secrets.key
    2020/12/01 11:41:29 Backup of cloud-init seed data at /var/www/ephemeral/configs/data.json-1606844489
    2020/12/01 11:41:29 Patched cloud-init seed data in place
    ```

    > NOTE: If using a non-default Certificate Autority (sealed secret), you'll need to verify that the vault chart overrides are updated with the correct sealed secret name to inject and use the ```--sealed-secret-name``` option to ```csi patch ca```.


3. Optionally, clean up the cloned shasta-cfg directory structure.

4. Restart basecamp to pickup changes to data.json

    ```bash
    pit:~ # systemctl restart basecamp
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

# Configure NTP on the LiveCD

Run this script to enable NTP on the LiveCD:

```bash
/root/bin/configure-ntp.sh
```

##### Safeguard: RAIDS / BOOTLOADERS / SquashFS / OverlayFS

Edit `/var/www/boot/script.ipxe` and align the following options as you see them here:

- `rd.live.overlay.reset=0` will prevent any overlayFS files from being cleared.
- `metal.no-wipe=1` will guard against touching RAIDs, disks, and partitions.

---
# Deployment

Once warmup / pre-flight checks are done the following procedure can be started.

## Manual Step 1: Ensure artifacts are in place

Mount the USB stick's data partition, and setup links for booting.

This will select the first boot image in each of the ceph and k8s directories and link it in /var/www.

```bash
pit:~ # /root/bin/set-sqfs-links.sh
```

Make sure the correct images were selected.
```bash
pit:~ # ls -l /var/www
```

## Manual Step 2: Set Boot Order

This step will ensure your NCNs follow 1.4 protocol for bootorder.

> For more information about NCN boot order check [101-BOOTING](101-NCN-BOOTING.md)

## Manual Step 3: Shutdown NCNs

#### Wiping for Re-Installs

If you're reinstalling, you should wipe the nodes. (This is automated by [MTL-1135](https://connect.us.cray.com/jira/browse/MTL-1135)).
For each node that is on, run the "Basic Wipe" defined in [Disk Cleanslate](051-DISK-CLEANSLATE.md).

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

*That's it, you're done!* Move onto the next step. On the other hand, below you can find a block of code for
one-time disk booting via `ipmitool`.

```bash
# ONE TIME BOOT INTO DISK; rebooting again will PXE; can run this everytime to reboot to disk for developers.
ipmitool -I lanplus -U $username -P $password -H ncn-s003-mgmt chassis bootdev disk options=efiboot
ipmitool -I lanplus -U $username -P $password -H ncn-s002-mgmt chassis bootdev disk options=efiboot
ipmitool -I lanplus -U $username -P $password -H ncn-s001-mgmt chassis bootdev disk options=efiboot
ipmitool -I lanplus -U $username -P $password -H ncn-w003-mgmt chassis bootdev disk options=efiboot
ipmitool -I lanplus -U $username -P $password -H ncn-w002-mgmt chassis bootdev disk options=efiboot
ipmitool -I lanplus -U $username -P $password -H ncn-w001-mgmt chassis bootdev disk options=efiboot
ipmitool -I lanplus -U $username -P $password -H ncn-m003-mgmt chassis bootdev disk options=efiboot
ipmitool -I lanplus -U $username -P $password -H ncn-m002-mgmt chassis bootdev disk options=efiboot

# for installs still using w001 for the LiveCD:
ipmitool -I lanplus -U $username -P $password -H ncn-m001-mgmt chassis bootdev disk options=efiboot
```

## Manual Step 4: Apply workarounds

Clone the workaround repo to have access to the workarounds needed to get through some known issues until they are fully fixed.

```bash
pit:~ # cd /root
pit:~ # git clone https://stash.us.cray.com/scm/spet/csm-installer-workarounds.git
```

### If there are any workarounds in the before-ncn-boot directory, run those now.   Instructions are in the README files.

## Manual Step 5: Boot Storage Nodes

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
# Connect to ncn-s002..
username=''
password=''
bmc='ncn-s002-mgmt'
pit:~ # echo ipmitool -I lanplus -U $username -P $password -H $bmc sol activate

# ..or print available consoles:
pit:~ # conman -q
pit:~ # conman -j ncn-s002
```

## Manual Step 6: Boot K8s

This will again just `echo` the commands.  Look them over and validate they are ok before running them.  This just `grep`s out the storage nodes so you only get the workers and managers.

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

> **NOTE:  We have seem some systems hang at pxe boot with the following messages on the console, if you hang here for more than five minutes, power the node off and back on again, this appears to be intermittent:

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



> **STOP and Check: Manually Inspect Storage**

```bash
pit:~ # csi pit validate --ceph
```

Run ceph -s and verify cluster is healthy from ncn-s001.nmn.  Verify that health is HEALTH_OK, and that we have mon, mgr, mds, osd and rgw services in the output:

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
Verify 3 storage config maps have been created (can run on ncn-s001.nmn):

```bash
ncn-s001:~ # kubectl get cm | grep csi-sc
cephfs-csi-sc                    1      8d
kube-csi-sc                      1      8d
sma-csi-sc                       1      8d
```

> **STOP and Check: Manually Check K8s**

Verify all nodes have joined the cluster (can run on any master/worker):

```bash
ncn-m002:~ # kubectl get nodes
NAME       STATUS   ROLES    AGE     VERSION
ncn-m002   Ready    master   7m31s   v1.18.6
ncn-m003   Ready    master   8m16s   v1.18.6
ncn-w001   Ready    <none>   7m21s   v1.18.6
ncn-w002   Ready    <none>   7m42s   v1.18.6
ncn-w003   Ready    <none>   8m02s   v1.18.6
```

Verify that all the pods in the kube-system namespace are running.  Make sure all pods except coredns have an IP starting with 10.252.

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

Now you can start **Installing platform services** [NCN Platform Install](006-NCN-PLATFORM-INSTALL.md)
