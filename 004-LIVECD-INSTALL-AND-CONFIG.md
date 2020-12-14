# Log in now with SSH

If you were on the Serial-over-LAN, now is a good time to log back in with SSH.  

## Manual Check 1 :: STOP :: Validate the LiveCD platform.

Check that IPs are set for each interface:

```bash
pit:~ # csi pit validate --network
```

## Manual Check 2 :: STOP :: Validate the Services

Now verify service health:
- dnsmasq, basecamp, and nexus should report HEALTHY and running.
- No podman container(s) should be dead.

```bash
pit:~ # csi pit validate --services
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

## Manual Check 3: Verify Outside Name Resolution

You should be able to resolve outside services like arti.dev.cray.com.

```bash
ping arti.dev.cray.com
```

Now you can start **Booting NCNs** [NCN Deploy](005-NCN-DEPLOY.md)
