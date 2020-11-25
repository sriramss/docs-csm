# Serivce Guides

This guide goes over directions for constructing various procedure such as constructing bootstrap-files 
or preflight checks/todos during initial racking.

The remainder of this page provides important nomenclature, notes, and environment
help.

#### Pre-Spring 2020 CRAY System Upgrade Notice
> This also applies for **systems running shasta-1.3 or older**.

Upgrades from shasta-1.3, or systems wired for shasta-1.3 topology, this guide may receive more installments for other files as time goes on and adjustments are needed.

### Table of Contents:

- [Environments](#environments)
- [Nomenclature & Constraings](#nomenclature--constraints)
- [Files](#files)

## Environments

These guides expect you to have access to either of the following things for working on a bare-metal
system (assuming freshly racked, or fresh-installing an existing system).

- LiveCD (for more information, see [LiveCD Creation](003-LIVECD-STARTUP.md))
- Linux and a Serial Console

If you do not have the LiveCD, or any other local Linux environment, this data collection
may be quicker the alternative method through the [303-NCN-METADATA-USB-SERIAL](303-NCN-METADATA-USB-SERIAL.md) page.

There are 2 parts to the NCN metadata file:
- Collecting the MAC of the BMC
- Collecting the MAC(s) of the shasta-network interface(s).

#### What is a "shasta-network interface"?

**This is not the High-Speed Network interface**

This is the interface, one or more, that comprise the NCNs' LACP link-aggregation ports.

##### LACP Bonding
NCNs may have 1 or more bond interfaces, which may be comprised from one or more physical interfaces. The
prefferred default configuration is 2 physical network interfaces per bond. The number 
of bonds themselves depends on your systems network topology.

For example, systems with 4 network interfaces on a given node could configure either of these
permutations (for redundancy minimums within Shasta cluster):
- 1 bond with 4 interfaces (i.e. `bond0`)
- 2 bonds with 2 interfaces each (i.e. `bond0` and `bond1`)

For more information, see [103-NETWORKING](103-NCN-NETWORKING.md) page for NCNs.

## Nomenclature & Constraints

> MACs ...
- "PXE MAC" or "BOOTSTRAP MAC" is the MAC address of the interface that your node will network boot over.
- "BOND MACS" is the MACs for the physical interfaces that your node will use for the various VLANs.
- "NMN MAC" is this is the same as the BOND MACs, but with emphasise on the vlan-participation.
> Relationships ...
- It is possible for both the **BOOTSTRAP & BOND0 MAC0** to be the **SAME**.
- BOND0 MAC0 and BOND0 MAC1 should **not** be on the same physical network card to establish redundancy for failed chips.
- On the other hand, if any nodes' capacity prevents it from being redundant, then MAC1 and MAC0 will still produce a valid configuration if they do reside on the same physical chip/card.
- The BMC MAC is the exclusive, dedicated LAN for the onboard BMC. It should not be swapped with any other device.

## Files

Each paragraph here will denote which pre-reqs are needed and which pages to follow 
for data collection.

--- 

### `ncn_metadata.csv`

Unless your system is sans-onboards, meaning it does not use or does not have onboard NICs on the non-compute nodes, then these guides will be necessary before (re)constructing the `ncn_metadata.csv` file.
1. [Recabling from shasta-1.3 for shasta-1.4](050-MOVE-SITE-CONNECTIONS.md) (for machines still using w001 for BIS node)
2. [Enabling Network Boots over Spine Switches](304-NCN-PXE-RECABLE.md) (for shasta 1.3 machines)

The following two guides will assist with (re)creating `ncn_metadata.csv`
1. [Collecting BMC MAC Addresses](301-NCN-METADATA-BMC.md)
2. [Collecting NCN MAC Addresses](302-NCN-METADATA-BONDX.md)

## Refreshing the LiveCD

To refresh your liveCD's packages for this guide, you must have an internet connection
to the CRAY repositories -or- have obtained the package and served it from local-disk or
reachable internal endpoint.

Use the built-in alias:
```bash
pit:~ # refme
```

On the other hand you can use this command, and tailor it to your use:
```bash
zypper \
  --no-gpg-checks \
  --plus-repo=http://car.dev.cray.com/artifactory/shasta-premium/MTL/sle15_sp2_ncn/x86_64/dev/master/ \
  --plus-repo=http://car.dev.cray.com/artifactory/shasta-premium/MTL/sle15_sp2_ncn/noarch/dev/master/ \
  install
  -y \
  cray-site-init \
  metal-ipxe \
  metal-docs-ncn
```

# Author(s)

[Rusty Bunch](mailto:rustydb@hpe.com)

[1]: https://stash.us.cray.com/projects/MTL/repos/cray-pre-install-toolkit/browse
[2]: https://stash.us.cray.com/projects/MTL/repos/cray-site-init/browse
[3]: https://stash.us.cray.com/projects/MTL/repos/ipxe/browse