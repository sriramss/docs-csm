# Guide : Netbboot an NCN from a Spine

This page details how to migrate NCNs from depending on their onboard NICs for PXE booting, and booting
over the spine switches.

**This applies to Newer systems (Spring 2020 or newer)** where onboard NICs are still used.

This presents a need for migration for systems still using the legacy, preview topology. Specifically,
systems with onboard connections to their leaf switches and NCNs need to disable/remove that connection.

This onboard NCN port came from before spine-switches were added to the shasta-network topology. The onboard connection
  was responsible for every network (MTL/NMN/HMN/CAN) and was the sole driver of PXE booting for. Now, NCNs use bond interfaces and spine switches for those networks,
   however some older systems still have this legacy connection to their leaf switches and solely use it for PXE booting. This NIC is not used during runtime, and NCNs in this state should enable PXE within their PCIe devices' OpROMs and disable/remove this onboard connection.

## Enabling UEFI PXE Mode

##### Mellanox

This uses the [Mellanox CLI Tools][1] for configuring UEFI PXE from the Linux command line.

You can install these tools onto the LiveCD (Cray Pre-Install Toolkit), which already has dependencies installed.

```bash
pit:~ # wget https://www.mellanox.com/downloads/MFT/mft-4.15.1-9-x86_64-rpm.tgz
pit:~ # tar -xzvf mft-4.15.1-9-x86_64-rpm.tgz
pit:~ #/mft-4.15.1-9-x86_64-rpm/RPMS # cd mft-4.15.1-9-x86_64-rpm/RPMS
pit:~ #/mft-4.15.1-9-x86_64-rpm/RPMS # rpm -ivh ./mft-4.15.1-9.x86_64.rpm
pit:~ #/mft-4.15.1-9-x86_64-rpm/RPMS # cd
pit:~ # mst start
```

Use this snippet to print out device name and current UEFI PXE state.
```bash
# Print name and current state.
mst status
for MST in $(ls /dev/mst/*); do
    mlxconfig -d ${MST} q | egrep "(Device|EXP_ROM)"
done
```
Use this snippet to enable and dump UEFI PXE state.
```bash
# Set UEFI to YES
for MST in $(ls /dev/mst/*); do
    echo ${MST}
    mlxconfig -d ${MST} -y set EXP_ROM_UEFI_x86_ENABLE=1
    mlxconfig -d ${MST} -y set EXP_ROM_PXE_ENABLE=1
    mlxconfig -d ${MST} q | egrep "EXP_ROM"
done
```

Your Mellanox is now configured for PXE booting.

##### QLogic FastLinq

These should already be configured for PXE booting.

See [#casm-triage][2] if this is not the case.

## Disabling/Removing On-Board Connections

The onboard connection can be disabled a few ways, short of removing the physical connection one
may shutdown the switchport as well.

If you can remove the physical connection, this is preferred and can be done so after enabling PXE on
the PCIe cards.

If you want to disable the connection, you will need to login to your respective leaf switch.
1. Connect over your medium of choice:
    ```bash 
    # SSH over METAL MANAGEMENT
    pit:~ # ssh admin@10.1.0.2
    # SSH over NODE MANAGEMENT
    pit:~ # ssh admin@10.252.0.2
    # SSH over HARDWARE MANAGEMENT
    pit:~ # ssh admin@10.254.0.2  
    
    # or.. serial (device name will vary).
    pit:~ # minicom -b 115200 -D /dev/tty.USB1 
    ```
2. Enter configuration mode
    ```sh
    $> configure terminal
    (config)#>  
    ```
3. Disable the NCN interfaces - check your SHCD for reference before continuing.
    ```
    (config)#> interface range 1/1/2-1/1/10  
    (config)#> shutdown  
    (config)#> write memory  
    ```

You're done.

You can enable them again at anytime by switching the `shutdown` command out for `no shutdown`.


[1]: http://www.mellanox.com/page/management_tools
[2]: https://cray.slack.com/messages/casm-triage