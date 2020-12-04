# Platform Install

This page will go over how to install all of the CSM manifests 


1. Copy the kubernetes config to the LiveCD to be able to use kubectl with current admin credentials. 
    ```bash
    pit:~ # mkdir ~/.kube
    pit:~ # scp ncn-m002.nmn:/etc/kubernetes/admin.conf ~/.kube/config
    ```
    Now you can run `kubectl get nodes` to see the nodes in the cluster.

2. Check out the shasta-cfg repo for your system. Replace `sif` with your system name.

    > **NOTE: This repository must be synced with the master branch of `stable` to deploy the appropriate manifests.**

    ```bash
    pit:~ # export system_name=sif
    pit:~ # cd /root
    pit:~ # git clone https://stash.us.cray.com/scm/shasta-cfg/${system_name}.git
    pit:~ # cd ${system_name}
    ```

    Make sure the IP addresses in the customizations.yaml file in this repo align with the IPs generated in CSI.  In particular, pay careful attention to
    spec.network.static_ips.dns.site_to_system_looksups
    spec.network.static_ips.ncn_masters
    spec.network.static_ips.ncn_storage

3. Generate various manifests

    > NOTE: the call to manifestgen should be done via ${system_name}/deploy/generate.sh when we're ready to use all manifests

    ```bash
    pit:~ # mkdir -p ./build/manifests
    pit:~ # manifestgen -c customizations.yaml -i ./manifests/platform.yaml > ./build/manifests/platform.yaml
    pit:~ # manifestgen -c customizations.yaml -i ./manifests/keycloak-gatekeeper.yaml > ./build/manifests/keycloak-gatekeeper.yaml
    pit:~ # manifestgen -c customizations.yaml -i ./manifests/sysmgmt.yaml > ./build/manifests/sysmgmt.yaml
    pit:~ # manifestgen -c customizations.yaml -i ./manifests/core-services.yaml > ./build/manifests/core-services.yaml
    ```

4. Run the deploydecryptionkey.sh script provided by the shasta-cfg/<system_name>.git repo.

    ```bash
    pit:~ # ./deploy/deploydecryptionkey.sh
    ```

5. Run loftsman against the platform and keycloak-gatekeeper manifests using shasta-cfg/<system_name> provided-script.

    ```bash
    pit:~ # ./deploy/deploy.sh ./build/manifests/platform.yaml dtr.dev.cray.com http://packages.local:8081/repository/helmrepo.dev.cray.com/
    pit:~ # ./deploy/deploy.sh ./build/manifests/keycloak-gatekeeper.yaml dtr.dev.cray.com http://packages.local:8081/repository/helmrepo.dev.cray.com/
    ```

    This should execute these manifests without error.


6. If there are any workarounds in the after-platform-manifest directory of the workarounds repository, run those now.   Instructions are in the README files.

    ```bash
    pit:~ #  cd /root/csm-installer-workarounds
    pit:~ #  cd after-platform-manifest
    ```

7. Deploy the metallb configuration

    ```bash
    pit:~ # kubectl apply -f /var/www/ephemeral/prep/${system_name}/metallb.yaml
    ```

8. Run loftsman against the core-services manifest using shasta-cfg/<system_name> provided-script.

    ```bash
    pit:~ # cd /root/${system_name}
    pit:~ # ./deploy/deploy.sh ./build/manifests/core-services.yaml dtr.dev.cray.com http://packages.local:8081/repository/helmrepo.dev.cray.com/
    ```

9. Run loftsman against the sysmgmt manifest using shasta-cfg/<system_name> provided-script.

    ```bash
    pit:~ # ./deploy/deploy.sh ./build/manifests/sysmgmt.yaml dtr.dev.cray.com http://packages.local:8081/repository/helmrepo.dev.cray.com/
    ```

10. If there are any workarounds in the after-sysmgmt-manifest directory of the workarounds repository, run those now.   Instructions are in the README files.

    ```bash
    pit:~ #  cd /root/csm-installer-workarounds
    pit:~ #  cd after-sysmgmt-manifest
    ```

