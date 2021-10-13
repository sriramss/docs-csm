

## Change Passwords and Credentials

There are many passwords and credentials used in different contexts to manage the system. These
can be changed as needed. Their initial settings are documented, so it is recommended to change
them during or soon after a CSM software installation.

See the following topics for more information:

   * [Manage System Passwords](../security_and_authentication/Manage_System_Passwords.md)
      * Keycloak
      * Gitea
      * Grafana
      * Kiali
      * Management Network Switches
      * Redfish Credentials
      * System Controllers (in a Liquid-cooled cabinet)
   * [Update NCN Passwords](../security_and_authentication/Update_NCN_Passwords.md)
   * [Change Root Passwords for Compute Nodes](../security_and_authentication/Change_Root_Passwords_for_Compute_Nodes.md)
   * [Change the Keycloak Admin Password](../security_and_authentication/Change_the_Keycloak_Admin_Password.md)
   * [Set BMC Credentials](../system_configuration_service/Set_BMC_Credentials.md)


### Passwords Managed in Other Product Streams

Refer to the following product stream documentation for detailed procedures about updating passwords for compute nodes and User Access Nodes (UANs).

**Cray Operating System (COS):** To update the root password for compute nodes, refer to "Set Root Password for Compute Nodes" in the COS product stream documentation for more information. 

**User Access Node (UAN):** Refer to "Create UAN Boot Images" in the UAN product stream documenation for the steps required to change the password on UANs. The "uan_shadow" header in the "UAN Ansible Roles" section includes more context on setting the root password on UANS.


