
## Reconfigure the externaldns-coredns Server IP Address

Update the IP address value for the externaldns-coredns server when reconfiguring the
system. During installation, the externaldns-coredns IP address is assigned to
spec.loadBalancerIP on the cray-externaldns-coredns-tcp and cray-externaldns-coredns-udp services
in the services namespace.To change the DNS IP without reinstalling the system, patch the 
configuration of cray-externaldns-coredns-tcp and cray-externaldns-coredns-udp services to
set thespec.loadBalancerIP field to the appropriate value.

### Procedure

1. View the current IP address.

```
ncn-w001# kubectl -n services get service | grep cray-externaldns-coredns-
cray-externaldns-coredns-tcp        LoadBalancer   10.27.85.163    10.102.14.113   53:30603/TCP        154d
cray-externaldns-coredns-udp        LoadBalancer   10.28.138.151   10.102.14.113   53:31208/UDP        154d
```

2. Patch the configuration of cray-externaldns-coredns-tcp.

In the following example, the `spec.loadBalancerIP` field is set to 10.102.10.114. Substitute the value of
the IP address before running the command.

```
ncn-w001# kubectl patch service -n services cray-externaldns-coredns-tcp -p '{"spec":{"loadBalancerIP": "10.102.10.114"}}'
service/cray-externaldns-coredns-tcp patched
```

3. Patch the configuration of cray-externaldns-coredns-udp.

In the following example, the `spec.loadBalancerIP` field is set to 10.102.10.114. Substitute the value of
the IP address before running the command. The loadBalancerIP address must be the same as the one used
for the -tcp service above.

```
ncn-w001# kubectl patch service -n services cray-externaldns-coredns-udp -p '{"spec":{"loadBalancerIP": "10.102.10.114"}}'
service/cray-externaldns-coredns-udp patched
```

4. View the IP address again to verify that the changes have been made.

```
ncn-w001# kubectl -n services get service | grep cray-externaldns-coredns-
cray-externaldns-coredns-tcp        LoadBalancer   10.27.85.163    10.102.14.113   53:30603/TCP        154d
cray-externaldns-coredns-udp        LoadBalancer   10.28.138.151   10.102.14.113   53:31208/UDP        154d
```


## Update the System Name Servers

Modify the default localization after system installation and update the onsite nameserver IP addresses.

### Procedure

1. Remove the default name servers (172.30.84.40 172.31.84.40) from `NETCONFIG_DNS_STATIC_SERVERS`
on each of the non-compute nodes (NCNs).

The `NETCONFIG_DNS_STATIC_SERVERS` value is located in the `/etc/sysconfig/network/config` directory.

```
NETCONFIG_DNS_STATIC_SERVERS="10.252.0.4 10.92.100.225 172.30.84.40 172.31.84.40"
```

2. Replace these default name server IP addresses in the ncn_dns_static_servers variable
in `/opt/cray/crayctl/ansible_framework/customer_runbooks/customer_var.yml` with the
onsite name server IP addresses.

```
ncn-w001# vi /opt/cray/crayctl/ansible_framework/customer_runbooks/customer_var.yml
...
ncn_dns_static_servers: 
  - 172.30.84.40
  - 172.31.84.40
```

## Reconfigure the Customer Access Network (CAN)

Update the CAN variables that were created during system installation. When
reconfiguring the CAN, the subnets and IP addresses must be updated to reflect the
values for used at the customer site.

### Procedure

1. Update the CAN variables in `/opt/cray/crayctl/ansible_framework/customer_runbooks/customer_var.yml` to specify
the subnets and IP addresses for the customer site.

```
ncn-w001# /opt/cray/crayctl/ansible_framework/customer_runbooks/customer_var.yml
customer_access_network: 10.101.8.0/24
customer_access_gateway: 10.101.8.20
customer_access_metallb_protocol: bgp
customer_access_metallb_address_pool: 10.101.8.128/25
customer_access_static_metallb_protocol: bgp
customer_access_static_metallb_address_pool:  10.101.8.112/28
```

2. Run the reconfig-can.sh script after changing the CAN variables.

  ```
  ncn-w001# ./reconfig-can.sh
  usage:   ./reconfig-can.sh <new-can-dns-ip>
  example: ./reconfig-can.sh 10.101.12.112
  ncn-w001# ./reconfig-can.sh NEW-CAN-DNS-IP

  The reconfig-can.sh script does the following steps:

  1. Saves all external LoadBalancer services.

  2. Edits the services to remove immutable values and changes the LoadBalancerIP for the exeternaldns-coredns services to the NEW-CAN-DNS-IP.

  3. Deletes the external LoadBalancer services. Existing services must be deleted before the new MetalLBconfiguration map will apply successfully.

  4. Reconfigures the CAN on the NCNs and for MetalLB external services by calling the following playbook.

  ```
  ansible-playbook /opt/cray/crayctl/ansible_framework/customer_runbooks/can-setup.yml
  ansible-playbook /opt/cray/crayctl/ansible_framework/customer_runbooks/metallb-localize.yml
  ```

  5. Restarts the external LoadBalancer services.

3. Verify the changes to the CAN have been made.

  a. Confirm the two externaldns-coredns services are running and the `EXTERNAL-IP` value is the `NEW-CAN-DNS-IP`.

  In the following example, the CAN DNS IP is 10.101.8.112.

  ```
  ncn-w001# kubectl get services -n services | grep "NAME\|externaldns-coredns-[tcp,udp]"
  NAME                                          TYPE           CLUSTER-IP      EXTERNAL-IP     PORT(S)                      AGE
  cray-externaldns-coredns-tcp                  LoadBalancer   10.24.248.62    10.101.8.112    53:31464/TCP                 21h
  cray-externaldns-coredns-udp                  LoadBalancer   10.30.215.64    10.101.8.112    53:30736/UDP                 21h
  ```

  b. Verify that all other external services have an `EXTERNAL-IP` value within the new `customer_access_metallb_address_pool`.

  In the following example, the value is 10.101.8.128/25, which is in the defined 10.101.8.128 -10.101.8.255 range in `customer_access_metallb_address_pool`.

  ```
  ncn-w001# kubectl get services -A | grep LoadBalancer | grep 10.101.8
  NAMESPACE        NAME                                                    TYPE           CLUSTER-IP      EXTERNAL-IP     PORT(S)                      AGE
  ceph-rgw         cray-s3                                                 LoadBalancer   10.30.85.255    10.101.8.131    8080:32334/TCP               21h
  ims              cray-ims-571aa7f3-947a-4598-9bbd-22531efa7c11-service   LoadBalancer   10.29.224.142   10.101.8.130    22:32757/TCP                 21h
  ims              cray-ims-6769b8fe-22ea-4a4c-8d4b-375cd4ceca74-service   LoadBalancer   10.23.156.183   10.101.8.138    22:30683/TCP                 21h
  ims              cray-ims-98d107c8-fe0c-4b8a-aa62-945c5ac29569-service   LoadBalancer   10.28.13.223    10.101.8.129    22:31945/TCP                 21h
  istio-system     istio-ingressgateway-can                                LoadBalancer   10.26.81.146    10.101.8.135    80:30974/TCP,443:31928/TCP   21h
  services         cray-externaldns-coredns-tcp                            LoadBalancer   10.24.248.62    10.101.8.112    53:31464/TCP                 21h
  services         cray-externaldns-coredns-udp                            LoadBalancer   10.30.215.64    10.101.8.112    53:30736/UDP                 21h
  services         cray-keycloak-gatekeeper-ingress                        LoadBalancer   10.31.77.220    10.101.8.137    443:30901/TCP                21h
  sma              rsyslog-aggregator-can                                  LoadBalancer   10.27.16.220    10.101.8.133    514:31722/TCP,8514:32679/TCP 21h
  sma              rsyslog-aggregator-can-udp                              LoadBalancer   10.18.118.248   10.101.8.133    514:31014/UDP,8514:30006/UDP 21h
  user             uai-ctuser-1570d69a-ssh                                 LoadBalancer   10.20.68.205    10.101.8.136    22:30076/TCP                 21h
  user             uai-dmb-b996ea2c-ssh                                    LoadBalancer   10.25.35.165    10.101.8.128    22:30451/TCP                 21h
  user             uai-kglaser-1f4bd492-ssh                                LoadBalancer   10.24.117.100   10.101.8.134    22:30246/TCP                 21h
  user             uai-vers-3413f82b-ssh                                   LoadBalancer   10.17.178.6     10.101.8.132    22:30081/TCP                 21h
  ```

4. Edit `/opt/cray/site-info/customizations.yml` and set the new externaldns-coredns external IP.

  The following command will ensure that any future deploys do not lose this change.

  ```
  ncn-w001# vi /opt/cray/site-info/customizations.yml
  ...
  site_to_system_lookups: "10.101.8.112"
  ```

5. Copy the changes made to the `/opt/cray/crayctl/ansible_framework/customer_runbooks/customer_var.yml` file to 
   `/root/system-specific-files/customer_var.yml`.

  ```
  ncn-w001# cp /opt/cray/crayctl/ansible_framework/customer_runbooks/customer_var.yml /root/system-specific-files/customer_var.yml
  ```

## Change the LDAP Server IP for Existing LDAP Server Content

### Prerequisites
The contents of the new LDAP server are the same as the previous LDAP server. For example, it is a replica or
was restored from a backup.

The IP address that Keycloak is using for the LDAP server can be changed. In the case where the new LDAP server
has the same contents as the previous LDAP server, edit the LDAP user federation to switch Keycloak to use the 
new LDAP server.  Refer to [Insert link]Change the LDAP Server IP for New LDAP Server Content if the LDAP server is being 
replaced by a different LDAP server that has different content.

Follow the steps in only one of the sections below depending on if it is preferred to use the Keycloak REST API or
Keycloak administration console UI.

### Procedure

#### Use The Keycloak Administration Console UI

  1. Log in to the administration console.  See [Insert link]Access the Keycloak User Management UI for more information.

  2. Click on `User Federation` under the `Configure` header of the navigation panel on the left side of the page.

  3. Click on the LDAP provider in the `User Federation` table.  This will bring up a form to edit the LDAP user federation.

  4. Change the `Connection URL` value in the LDAP user federation form to use the new IP address.

  5. Click the `Save` button at the bottom of the form.

  6. Click the `Synchronize all users` button.  This may take a while depending on the number of users and groups in the LDAP server.
     When the synchronize process completes, the pop-up will show that the update was successful. There should be minimal or no 
     changes because the contents of the servers are the same.

#### Use The Keycloak REST API

  1. Create a function to get a token as a Keycloak master administrator.

  ```
  MASTER_USERNAME=$(kubectl get secret -n services keycloak-master-admin-auth -ojsonpath='{.data.user}' | base64 -d)
  MASTER_PASSWORD=$(kubectl get secret -n services keycloak-master-admin-auth -ojsonpath='{.data.password}' | base64 -d)

  function get_master_token {
    curl -ks -d client_id=admin-cli -d username=$MASTER_USERNAME -d password=$MASTER_PASSWORD -d grant_type=password https://api-gw-service-nmn.local/keycloak/realms/master/protocol/openid-connect/token | python -c "import sys.json; print json.load(sys.stdin)['access_token']"
  }
  ```

  2. Get the component ID for the LDAP user federation.

  ```
  ncn-w001# COMPONENT_ID=$(curl -s -H "Authorization: Bearer $(get_master_token)" \
  https://api-gw-service-nmn.local/keycloak/admin/realms/shasta/components \
  | jq -r '.[] | select(.providerId=="ldap").id')
  ncn-w001# echo $COMPONENT_ID57817383-e4a0-4717-905a-ea343c2b5722
  ```

  3. Get the current representation of the LDAP user federation.

  ```
  ncn-w001# curl -s -H "Authorization: Bearer $(get_master_token)" \
  https://api-gw-service-nmn.local/keycloak/admin/realms/shasta/components/$COMPONENT_ID \
  | jq . > keycloak_ldap.json

  {  
    "id": "57817383-e4a0-4717-905a-ea343c2b5722",
    "name": "shasta-user-federation-ldap",
    "providerId": "ldap",
    "providerType": "org.keycloak.storage.UserStorageProvider",
    "parentId": "09580343-fc55-4951-84ee-1c73b3a7ad29",
    "config": {
      "pagination": [
        "true"
      ],
      "fullSyncPeriod": [
        "-1"
      ],
  ...
      "connectionUrl": [
        "ldap://10.248.0.59"
      ],
  ...
  ```

  4. Edit the `keycloak_ldap.json` file and set the `connectionUrl` string to the new URL with the new IPaddress.

  ```
  ncn-w001# vi keycloak_ldap.json
  ```

  5. Apply the updated `keycloak_ldap.json` file to the Keycloak server.

  The output should show the response code is 204.

  ```
  ncn-w001# curl -i -XPUT -H "Authorization: Bearer $(get_master_token)" -H \
  "Content-Type: application/json" -d @keycloak_ldap.json \
  https://api-gw-service-nmn.local/keycloak/admin/realms/shasta/components/$COMPONENT_ID
  HTTP/2 204
  ...
  ```

## Change the LDAP Server IP for New LDAP Server Content

### Prerequisites
The LDAP server is being replaced by a different LDAP server that has different contents. For example, different users and groups.

Delete the old LDAP user federation and create a new one. This procedure should only be done if the LDAP server is being 
replaced by a different LDAP server that has different contents.  
Refer to [Insert link] Change the LDAP Server IP for Existing LDAP Server Content if the new LDAP server content matches the previous LDAP server content.

### Procedure

1. Remove the LDAP user federation from Keycloak.

Follow the procedure in [Insert link] Remove the LDAP User Federation from Keycloak. 

2. Re-add the LDAP user federation in Keycloak.

Follow the procedure in [Insert link] Add LDAP User Federation.

## Remove the LDAP User Federation from Keycloak

### Prerequisites
LDAP user federation is currently configured in Keycloak.

Use the Keycloak UI or Keycloak REST API to remove the LDAP user federation from Keycloak.
Removing user federation is useful if the LDAP server was decommissioned or if the administrator would like to make changes to the 
Keycloak configuration using the Shasta Keycloak user localization tool.

Follow the steps in only one of the sections below depending on if it is preferred to use the Keycloak REST API or
Keycloak administration console UI.

### Procedure

#### Use The Keycloak Administration Console UI

  1. Log in to the administration console.  See [Insert link] Access the Keycloak User Management UI for more information.

  2. Click on `User Federation` under the `Configure` header of the navigation panel on the left side of the page.

  3. Click on the `Delete` button on the line for the LDAP provider in the User Federation table.

#### Use The Keycloak REST API

  1. Create a function to get a token as a Keycloak master administrator.

  ```
  MASTER_USERNAME=$(kubectl get secret -n services keycloak-master-admin-auth -ojsonpath='{.data.user}' | base64 -d)
  MASTER_PASSWORD=$(kubectl get secret -n services keycloak-master-admin-auth -ojsonpath='{.data.password}' | base64 -d)

  function get_master_token {
    curl -ks -d client_id=admin-cli -d username=$MASTER_USERNAME -d password=$MASTER_PASSWORD -d grant_type=password https://api-gw-service-nmn.local/keycloak/realms/master/protocol/openid-connect/token | python -c "import sys.json; print json.load(sys.stdin)['access_token']"
  }
  ```

  2. Get the component ID for the LDAP user federation.

  ```
  ncn-w001# COMPONENT_ID=$(curl -s -H "Authorization: Bearer $(get_master_token)" \
  https://api-gw-service-nmn.local/keycloak/admin/realms/shasta/components \
  | jq -r '.[] | select(.providerId=="ldap").id')
  ncn-w001# echo $COMPONENT_ID57817383-e4a0-4717-905a-ea343c2b57226
  ```

  3. Delete the LDAP user federation by performing a DELETE operation on the LDAP resource.

  The HTTP status code should be 204.

  ```
  ncn-w001# curl -i -XDELETE -H "Authorization: Bearer $(get_master_token)" \
  https://api-gw-service-nmn.local/keycloak/admin/realms/shasta/components/$COMPONENT_ID
  HTTP/2 204
  ...
  ```

## Add LDAP User Federation

### Prerequisites
LDAP user federation isn't currently configured in Keycloak. For example, if it wasn't configured in Keycloak when
the system was initially installed or the LDAP user federation was removed.

Add LDAP user federation using the Shasta Keycloak localization tool.

### Procedure

  1. Update the LDAP settings in the `/opt/cray/crayctl/ansible_framework/customer_runbooks/customer_var.yml` file.

  ```
  ncn-w001# vi /opt/cray/crayctl/ansible_framework/customer_runbooks/customer_var.yml
  ```
  
  2. Run the keycloak-users.yml playbook to update the settings in the Kubernetes cluster ConfigMap and Secret that 
     the Keycloak localization tool uses.

  ```
  ncn-w001# ansible-playbook keycloak-users.yml
  ```

  3. Resubmit the Kubernetes Job that runs the Keycloak localization tool.

    a. Resubmit the keycloak-users-localize job.

    The output might appear slightly different than in the example below.

    ```
    ncn-w001# kubectl get job -n services -l app.kubernetes.io/name=cray-keycloak-users-localize -ojson | jq '.items[0]' > keycloak-users-localize-job.json
    ncn-w001# cat keycloak-users-localize-job.json | jq 'del(.spec.selector)' | \
    jq 'del(.spec.template.metadata.labels)' | kubectl replace --force -f -
    job.batch "keycloak-users-localize-1" deleted
    job.batch/keycloak-users-localize-1 replaced
    ```

    b. Watch the pod to check the status of the job.

    The pod will go through the normal Kubernetes states. It will stay in a `Running` state for a while, and then it will go to `Completed`.

    ```
    ncn-w001# kubectl get pods -n services | grep keycloak-users-localize
    keycloak-users-localize-1-sk2hn                                0/2     Completed   0          2m35s
    ```

    c. Check the pod's logs.

    Replace the `KEYCLOAK_POD_NAME` value with the pod name from the previous step.

    ```
    ncn-w001# kubectl logs -n services KEYCLOAK_POD_NAME keycloak-localize
    <logs showing it's updated the "s3" objects and ConfigMaps>
    2020-07-20 18:26:15,774 - INFO    - keycloak_localize - keycloak-localize complete
    ```

    d. Sync the users and groups from Keycloak to the compute nodes.

    Wait for the keycloak-users-localize job to complete before running the following command. This runs an Ansible role on all
    computes defined in the Ansible inventory that pulls the password and groups files from S3 and replaces the files on the
    computes with the current contents.

    ```
    ncn-w001# ansible-playbook keycloak-users-compute.yml
    ```

