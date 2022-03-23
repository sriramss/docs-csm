# Stage 0 - Prerequisites and Preflight Checks

> **NOTE:** CSM-1.0.1 or higher is required in order to upgrade to CSM-1.2.0

- [Stage 0.1 - Install latest docs RPM](#install-latest-docs)
- [Stage 0.2 - Reduce CPU Limits If Needed](#reduce-cpu-limits)
- [Stage 0.3 - Prerequisites Check](#prerequisites-check)
- [Stage 0.4 - Backup VCS Data](#backup-vcs-data)

<a name="install-latest-docs"></a>

## Stage 0.1 - Install latest docs RPM

1. Install latest document RPM package:

   > The install scripts will look for the RPM in `/root`, so it is important that you copy it there.

   - Internet Connected

     ```bash
     ncn-m001# wget https://storage.googleapis.com/csm-release-public/csm-1.2/docs-csm/docs-csm-latest.noarch.rpm -P /root
     ncn-m001# rpm -Uvh --force /root/docs-csm-latest.noarch.rpm
     ```

   - Air Gapped (replace the PATH_TO below with the location of the rpm)

     ```bash
     ncn-m001# cp [PATH_TO_docs-csm-*.noarch.rpm] /root
     ncn-m001# rpm -Uvh --force /root/docs-csm-*.noarch.rpm
     ```

<a name="reduce-cpu-limits"></a>

## Stage 0.2 - Reduce CPU Limits If Needed

**`IMPORTANT`**

For TDS systems with only three worker nodes, prior to proceeding with this upgrade CPU limits **MUST** be lowered on several services in order for this upgrade to succeed. This step is executed automatically as part of [Stage 0.5](#prerequisites-check). See [TDS Lower CPU Requests](../../operations/kubernetes/TDS_Lower_CPU_Requests.md) for more information.

Independently, the `customizations.yaml` file will be edited automatically during upgrade for TDS systems prior to deploying new CSM services. See the file: `/usr/share/doc/csm/upgrade/1.2/scripts/upgrade/tds_cpu_requests.yaml` for these settings. If desired, this file can be modified (prior to proceeding with this upgrade) with different values if other settings are desired in the `customizations.yaml` file for this system.

For more information about modifying `customizations.yaml` and tuning based on specific systems, see [Post Install Customizations](https://github.com/Cray-HPE/docs-csm/blob/release/1.2/operations/CSM_product_management/Post_Install_Customizations.md).

<a name="prerequisites-check"></a>

## Stage 0.5 - Prerequisites Check

Run check script:

> **`IMPORTANT:`** If the password for the local Nexus `admin` account has
> been changed from the default `admin123` (not typical), then set the
> `NEXUS_PASSWORD` environment variable to the correct `admin` password
> before running prerequisites.sh!
>
> For example:
>
> ```bash
> ncn-m001# export NEXUS_PASSWORD=cu$t0m@DM1Np4s5w0rd
> ```
>
> Otherwise, a random 32-character base64-encoded string will be generated
> and updated as the default `admin` password when Nexus is upgraded.

- Internet Connected

  ```bash
  ncn-m001# /usr/share/doc/csm/upgrade/1.2/scripts/upgrade/prerequisites.sh --csm-version [CSM_RELEASE] --endpoint [ENDPOINT]
  ```

  **NOTE** ENDPOINT is optional for internal use. It is pointing to internal arti by default.

- Air Gapped

  ```bash
  ncn-m001# /usr/share/doc/csm/upgrade/1.2/scripts/upgrade/prerequisites.sh --csm-version [CSM_RELEASE] --tarball-file [PATH_TO_CSM_TARBALL_FILE]
  ```

**`IMPORTANT:`** If any errors are encountered, then potential fixes should be displayed where the error occurred. **IF** the upgrade `prerequisites.sh` script fails and does not provide guidance, then try rerunning it. If the failure persists, then open a support ticket for guidance before proceeding.

**`IMPORTANT:`** If the `NEXUS_PASSWORD` environment variable was set as previously mentioned, then remove it before continuing:

```bash
ncn-m001# export -n NEXUS_PASSWORD
ncn-m001# unset NEXUS_PASSWORD
```

**`OPTIONAL:`** Customizations.yaml has been updated in this step. If [using an external Git repository for managing customizations](../../install/prepare_site_init.md#version-control-site-init-files) as recommended,
clone a local working tree and commit appropriate changes to `customizations.yaml`.

For example:

```bash
ncn-m001# git clone <URL> site-init
ncn-m001# cd site-init
ncn-m001# kubectl -n loftsman get secret site-init -o jsonpath='{.data.customizations\.yaml}' | base64 -d - > customizations.yaml
ncn-m001# git add customizations.yaml
ncn-m001# git commit -m 'CSM 1.2 upgrade - customizations.yaml'
ncn-m001# git push
```

<a name="backup-vcs-data"></a>

## Stage 0.6 - Backup VCS Data

To prevent any possibility of losing configuration data, backup the VCS data and store it in a safe location. See [Version_Control_Service_VCS.md](../../operations/configuration_management/Version_Control_Service_VCS.md#backup-and-restore-data) for these procedures.

**`IMPORTANT:`** As part of this stage, **only perform the backup, not the restore**. The backup procedure is being done here as a precautionary step.

Once the above steps have been completed, proceed to [Stage 1](Stage_1.md).
