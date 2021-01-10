# Platform Install

This page will go over how to install CSM applications and services (i.e., into the CSM Kubernetes cluster).


1. Copy the Kubernetes config to the LiveCD to be able to use `kubectl` as cluster administrator. 
    ```bash
    pit:~ # mkdir ~/.kube
    pit:~ # scp ncn-m002.nmn:/etc/kubernetes/admin.conf ~/.kube/config
    ```
    Now you can run `kubectl get nodes` to see the nodes in the cluster.

2. Make sure the IP addresses in the `customizations.yaml` file in this repo align with the IPs generated in CSI.  

    > File location: `/var/www/ephemeral/prep/site-init/customizations.yaml`

    In particular, pay careful attention to:

    ```
    spec.network.static_ips.dns.site_to_system_lookups
    spec.network.static_ips.ncn_masters
    spec.network.static_ips.ncn_storage
    ```
     > TODO: For automation this should be checked, if this step is still used when automation lands.

3. Run the `deploydecryptionkey.sh` script

    ```bash
    pit:~/ # cd /var/www/ephemeral/prep/site-init/
    pit:/var/www/ephemeral/prep/site-init # ./deploy/deploydecryptionkey.sh
    ```

4. Change into the directory where you extracted the CSM Release distribution. Complete the CSM install by following instructions in ```INSTALL``` and as otherwise directed by the installer process.

    See [002-LIVECD-CREATION](002-LIVECD-CREATION.md) for further details.