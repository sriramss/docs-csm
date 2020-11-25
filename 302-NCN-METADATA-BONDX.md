# Collecting NCN MAC Addresses

This page will detail how to collect the NCN MAC addresses from a racked, shasta-1.4+ system.

After completing this guide, you will have the MAC addresses needed for the `ncn_metadata.csv` file's BMC  column.

## Procedure: iPXE Consoles

This procedure is faster for those with the LiveCD (CRAY Pre-Install Toolkit) it can be used to quickly
boot-check nodes to dump network device information without an OS. This works by accessing the PCI Configuration Space.

#### Requirements

1. LiveCD is configured (`csi pit validate` to verify.)
2. Conman is active (`conman -q` to see consoles.)
3. BMC MACs already collected

For help with either of those, see [LIVECD-SETUP](006-LIVECD-SETUP.md).

#### MAC Collection

1. (optional) shim the boot so nodes bail after dumping their netdevs. Removing the iPXE script will prevent network booting but beware of disk-boots. 
will prevent the nodes from continuing to boot and end in undesired states.
    ```bash
    pit:~ # mv /var/www/boot/script.ipxe /var/www/boot/script.ipxe.bak
    ```
2. Verify consoles are active with `conman -q`,
    ```bash
    pit:~ # conman -q
    ncn-m002-mgmt
    ncn-m003-mgmt
    ncn-s001-mgmt
    ncn-s002-mgmt
    ncn-s003-mgmt
    ncn-w001-mgmt
    ncn-w002-mgmt
    ncn-w003-mgmt
    ```

3. Now set the nodes to PXE boot and (re)start them.
    ```bash
    # Replace with actual username/passwords.
    username=bob
    password=alice
    
    # ALWAYS PXE BOOT; sets a system to PXE
    for node in $(conman -q | grep ncn | grep mgmt); do
        ipmitool -I lanplus -U $username -P $password -H $node chassis bootdev pxe options=efiboot,persistent
        if ipmitool -I lanplus -U $username -P $password -H $node power status =~ 'off' ; then 
            ipmitool -I lanplus -U $username -P $password -H $node power on
        else
            ipmitool -I lanplus -U $username -P $password -H $node power reset
        fi
    done
    ```
4. Now wait for the nodes to netboot. You can follow them with `conman -j ncn-*id*-mgmt` (use `conman -q` to see ). This takes less than 3 minutes, speed depends on how quickly your nodes POST.
5. Print off what's been found in the console logs, this snippet will omit duplicates from multiple boot attempts:
    ```bash
    for file in /var/log/conman/*; do
        echo $file
        grep -Eoh '(net[0-9] MAC .*)' $file | sort -u | grep PCI && echo -----
    done
    ```
6. From the output you must fish out 2 MACs to use for bond0, and 2 more to use for bond1 based on your topology.
    - Examine the output, you can use the table provided on [NCN Networking](103-NETWORKING.md) for referencing commonly seen devices.
    - Note that worker nodes also have the high-speed network cards. If you know these cards, you can filter their device IDs out from the above output using this snippet:
        ```bash
        unset did # clear it if you used it.
        did=1017 # ConnectX-5 example.
        for file in /var/log/conman/*; do
            echo $file
            grep -Eoh '(net[0-9] MAC .*)' $file | sort -u | grep PCI | grep -Ev "$did" && echo -----
        done
        ``` 
    - Note to filter out onboard NICs, or site-link cards, you can omit their device IDs as well. Use the above snippet but add the other IDs:
      **this snippet prints out only mgmt MACs, the `did` is the HSN and onboard NICs that is being ignored.**
        ```bash
        unset did # clear it if you used it.
        did='(1017|8086)'
        for file in /var/log/conman/*; do
            echo $file
            grep -Eoh '(net[0-9] MAC .*)' $file | sort -u | grep PCI | grep -Ev "$did" && echo -----
        done
        ```
7. If you are not using onboard NICs, skip to step 8 and ignore this step. 
    > Tip: Mind the index (3, 2, 1.... ; not 1, 2, 3)
    ```
    NCN Xname, NCN Role, NCN Subrole,BMC MAC,BOOTSTRAP MAC,BOND0 MAC0,BOND0 MAC1
    xXXXXcCsSSbBnN,Management,Storage3,********,************,BOND0 MAC0,BOND0 MAC1
    xXXXXcCsSSbBnN,Management,Storage2,********,************,BOND0 MAC0,BOND0 MAC1
    xXXXXcCsSSbBnN,Management,Storage1,********,************,BOND0 MAC0,BOND0 MAC1
    xXXXXcCsSSbBnN,Management,Worker3,********,************,BOND0 MAC0,BOND0 MAC1
    xXXXXcCsSSbBnN,Management,Worker2,********,************,BOND0 MAC0,BOND0 MAC1
    xXXXXcCsSSbBnN,Management,Worker1,********,************,BOND0 MAC0,BOND0 MAC1
    xXXXXcCsSSbBnN,Management,Master3,********,************,BOND0 MAC0,BOND0 MAC1
    xXXXXcCsSSbBnN,Management,Master2,********,************,BOND0 MAC0,BOND0 MAC1
    xXXXXcCsSSbBnN,Management,Master1,********,************,BOND0 MAC0,BOND0 MAC1
    ```

8. If you are not using onboard NICs, as is the new network modal for 1.4 use this format:
    > Tip: Mind the index (3, 2, 1.... ; not 1, 2, 3)
    ```
    NCN Xname, NCN Role, NCN Subrole,BMC MAC,BOOTSTRAP MAC,BOND0 MAC0,BOND0 MAC1
    xXXXXcCsSSbBnN,Management,Storage3,********,--BOND0 MAC0-,BOND0 MAC0,BOND0 MAC1
    xXXXXcCsSSbBnN,Management,Storage2,********,--BOND0 MAC0-,BOND0 MAC0,BOND0 MAC1
    xXXXXcCsSSbBnN,Management,Storage1,********,--BOND0 MAC0-,BOND0 MAC0,BOND0 MAC1
    xXXXXcCsSSbBnN,Management,Worker3,********,--BOND0 MAC0-,BOND0 MAC0,BOND0 MAC1
    xXXXXcCsSSbBnN,Management,Worker2,********,--BOND0 MAC0-,BOND0 MAC0,BOND0 MAC1
    xXXXXcCsSSbBnN,Management,Worker1,********,--BOND0 MAC0-,BOND0 MAC0,BOND0 MAC1
    xXXXXcCsSSbBnN,Management,Master3,********,--BOND0 MAC0-,BOND0 MAC0,BOND0 MAC1
    xXXXXcCsSSbBnN,Management,Master2,********,--BOND0 MAC0-,BOND0 MAC0,BOND0 MAC1
    xXXXXcCsSSbBnN,Management,Master1,********,--BOND0 MAC0-,BOND0 MAC0,BOND0 MAC1
    ```

## Procedure: Serial Consoles

For this, you will need to double-back to [NCN Metadata BMC](301-NCN-METADATA-BMC.md) and pick out
the MACs for your BOND from each spine switch.

> Tip: A PCIe card with dual-heads may go to either spine switch, meaning MAC0 ought to be collected from
> spine-01. Please refer to your cabling diagram, or actual rack (in-person).

1. Follow "Metadata BMC" on each spine switch that port1 and port2 of the bond isplugged into.
2. Usually the 2nd/3rd/4th/Nth MAC on the PCIe card will be a 0x1 or 0x2 deviation from the first port. If you confirm this, then collection
is quicker. 
