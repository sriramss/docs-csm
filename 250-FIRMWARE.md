# Firmware

## NCNs

Firmware is not updated during fresh-install. The bootstrap environment has capacity to upgrade, but it is more imperitive to standup services for a autonomy from the liveCD.

NCN firmware is updated following install by various firmware update services in the management plane (i.e. FAS). This can be done after the platform is online, after rebooting from the LiveCD.

Firmware upgrades while the LiveCD is in flight can be done, but are not part of the normal install flow. This is seen as triage, or recovery

## CNs (compute)

Firmware needs to be updated prior to install through the same services used for NCNs.


