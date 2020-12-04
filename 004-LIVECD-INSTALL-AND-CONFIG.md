# Manual Step 1: Interfaces

> Source qnd-1.4.sh to prepare the install env.

```bash
pit:~ # source /var/www/ephemeral/prep/qnd-1.4.sh
pit:~ # env
```

## Setup the Site-link 

External, direct access.

```bash
/root/bin/csi-setup-lan0.sh $site_cidr $site_gw $site_dns $site_nic
```

# Log in now with SSH

If you were on the Serial-over-LAN, now is a good time to log back in with SSH.  

> If you do log in with SSH, make you `source /var/www/ephemeral/prep/qnd-1.4.sh` again since you're logged in in a new session now.

## Setup the bond and vlan interfaces

### Copy the CSI generated ifcfg files into place 

> Note we are not copying in the ifcfg-lan0 file at this time

```bash
pit:~ # cp /var/www/ephemeral/prep/${system_name}/cpt-files/ifcfg-bond0 /etc/sysconfig/network
pit:~ # cp /var/www/ephemeral/prep/${system_name}/cpt-files/if*-vlan* /etc/sysconfig/network
```

### Bring up these interfaces

```bash
pit:~ # wicked ifup bond0 
pit:~ # wicked ifup vlan002 
pit:~ # wicked ifup vlan004 
pit:~ # wicked ifup vlan007 
```

## Manual Check 1 :: STOP :: Validate the LiveCD platform.

Check that IPs are set for each interface:

```bash
csi pit validate --network true
```

# Manual Step 2: Services

Copy the config files generated earlier by `csi config init` into /etc/dnsmasq.d and /etc/conman.conf.
```bash
cp /var/www/ephemeral/prep/${system_name}/dnsmasq.d/* /etc/dnsmasq.d
cp /var/www/ephemeral/prep/${system_name}/conman.conf /etc/conman.conf
systemctl restart dnsmasq
systemctl restart conman
```

## Manual Check 2 :: STOP :: Validate the Services

Now verify service health:
- dnsmasq, basecamp, and nexus should report HEALTHY and running.
- No podman container(s) should be dead.

```bash
csi pit validate --services true
```

> - If basecamp is dead, restart it with `systemctl restart basecamp`.
> - If dnsmasq is dead, restart it with `systemctl restart dnsmasq`.
> - If nexus is dead, restart it with `systemctl restart nexus`.

You should see two containers: nexus and basecamp

```
CONTAINER ID  IMAGE                                         COMMAND               CREATED     STATUS         PORTS   NAMES
496a2ce806d8  dtr.dev.cray.com/metal/cloud-basecamp:latest                        4 days ago  Up 4 days ago          basecamp
6fcdf2bfb58f  docker.io/sonatype/nexus3:3.25.0              sh -c ${SONATYPE_...  4 days ago  Up 4 days ago          nexus
```

# Manual Step 3: Access to External Services

To access outside services like Stash or Artifactory, we need to set up /etc/resolv.conf.  Make sure the /etc/resolv.conf includes the site DNS server at the end of the file.

```bash
nameserver 172.30.84.40
```

# Manual Check 3: Verify Outside Name Resolution

You should be able to resolve outside services like arti.dev.cray.com.

```bash
ping arti.dev.cray.com
```

Now you can start **Booting NCNs** [NCN Deploy](005-NCN-DEPLOY.md)
