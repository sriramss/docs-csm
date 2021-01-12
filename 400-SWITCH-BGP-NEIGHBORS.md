# Verify and Update BGP neighbors

This page will detail how-to manually configure and verify BGP neighbors on the management switches.

- How do I check the status of the BGP neighbors?
- log into the spine switches and run `show bgp ipv4 unicast summary` for Aruba/HPE switches and `show ip bgp summary` for Mellanox

- The BGP neighbors will be the worker NCN IPs on the NMN (node managmenet network) (VLAN002)
- On the Aruba/HPE switches properly configured BGP will look like the following.

```
sw-spine01# show bgp ipv4 unicast summary
VRF : default
BGP Summary
-----------
 Local AS               : 65533        BGP Router Identifier  : 10.252.0.1     
 Peers                  : 4            Log Neighbor Changes   : No             
 Cfg. Hold Time         : 180          Cfg. Keep Alive        : 60             

 Neighbor        Remote-AS MsgRcvd MsgSent   Up/Down Time State        AdminStatus
 10.252.0.3      65533       31457   31474   00m:02w:04d  Established   Up         
 10.252.2.8      65533       54730   62906   00m:02w:04d  Established   Up         
 10.252.2.9      65533       54732   62927   00m:02w:04d  Established   Up         
 10.252.2.18     65533       54732   62911   00m:02w:04d  Established   Up 
 ```
 on the Mellanox switches the output should look like the following
 
 ```
 sw-spine01 [standalone: master] # show ip bgp summary 

VRF name                  : default
BGP router identifier     : 10.252.0.1
local AS number           : 65533
BGP table version         : 308
Main routing table version: 308
IPV4 Prefixes             : 261
IPV6 Prefixes             : 0
L2VPN EVPN Prefixes       : 0

------------------------------------------------------------------------------------------------------------------
Neighbor          V    AS           MsgRcvd   MsgSent   TblVer    InQ    OutQ   Up/Down       State/PfxRcd        
------------------------------------------------------------------------------------------------------------------
10.252.0.7        4    65533        37421     42948     308       0      0      12:23:16:07   ESTABLISHED/53
10.252.0.8        4    65533        37421     42920     308       0      0      12:23:16:07   ESTABLISHED/51
10.252.0.9        4    65533        37420     42962     308       0      0      12:23:16:07   ESTABLISHED/51
10.252.0.10       4    65533        37423     42968     308       0      0      12:23:16:07   ESTABLISHED/53
10.252.0.11       4    65533        37423     42980     308       0      0      12:23:16:06   ESTABLISHED/53
```
- If the BGP neighbors are not in the `ESATBLISHED` state make sure the IPs are correct for the route-map and BGP configuration.
- If IPs are incorrect you will have to update the configuration to match the IPs, the configuration below will need to be edited.
- You can get the NCN IPs from the CSI generated files (NMN.yaml, CAN.yaml, HMN.yaml)

Aruba
```
route-map rm-ncn-w001 permit seq 10
     match ip address prefix-list pl-nmn
     set ip next-hop 10.252.2.8
route-map rm-ncn-w001 permit seq 20
     match ip address prefix-list pl-hmn
     set ip next-hop 10.254.2.27
route-map rm-ncn-w001 permit seq 30
     match ip address prefix-list pl-can
     set ip next-hop 10.103.10.10
route-map rm-ncn-w002 permit seq 10
     match ip address prefix-list pl-nmn
     set ip next-hop 10.252.2.9
route-map rm-ncn-w002 permit seq 20
     match ip address prefix-list pl-hmn
     set ip next-hop 10.254.2.25
route-map rm-ncn-w002 permit seq 30
     match ip address prefix-list pl-can
     set ip next-hop 10.103.10.9
route-map rm-ncn-w003 permit seq 10
     match ip address prefix-list pl-nmn
     set ip next-hop 10.252.2.18
route-map rm-ncn-w003 permit seq 20
     match ip address prefix-list pl-hmn
     set ip next-hop 10.254.2.26
route-map rm-ncn-w003 permit seq 30
     match ip address prefix-list pl-can
     set ip next-hop 10.103.10.11
!                                                              
router bgp 65533
    bgp router-id 10.252.0.1
    maximum-paths 8
    neighbor 10.252.0.3 remote-as 65533
    neighbor 10.252.2.8 remote-as 65533
    neighbor 10.252.2.9 remote-as 65533
    neighbor 10.252.2.18 remote-as 65533
    address-family ipv4 unicast
        neighbor 10.252.0.3 activate
        neighbor 10.252.2.8 activate
        neighbor 10.252.2.8 route-map rm-ncn-w001 in
        neighbor 10.252.2.9 activate
        neighbor 10.252.2.9 route-map rm-ncn-w002 in
        neighbor 10.252.2.18 activate
        neighbor 10.252.2.18 route-map rm-ncn-w003 in
    exit-address-family
```
Mellanox
```
## Route-maps configuration
##
   route-map rm-ncn-w001 permit 10 match ip address pl-nmn
   route-map rm-ncn-w001 permit 10 set ip next-hop 10.252.0.7
   route-map rm-ncn-w001 permit 20 match ip address pl-hmn
   route-map rm-ncn-w001 permit 20 set ip next-hop 10.254.0.7
   route-map rm-ncn-w001 permit 30 match ip address pl-can
   route-map rm-ncn-w001 permit 30 set ip next-hop 10.103.8.7
   route-map rm-ncn-w002 permit 10 match ip address pl-nmn
   route-map rm-ncn-w002 permit 10 set ip next-hop 10.252.0.8
   route-map rm-ncn-w002 permit 20 match ip address pl-hmn
   route-map rm-ncn-w002 permit 20 set ip next-hop 10.254.0.8
   route-map rm-ncn-w002 permit 30 match ip address pl-can
   route-map rm-ncn-w002 permit 30 set ip next-hop 10.103.8.8
   route-map rm-ncn-w003 permit 10 match ip address pl-nmn
   route-map rm-ncn-w003 permit 10 set ip next-hop 10.252.0.9
   route-map rm-ncn-w003 permit 20 match ip address pl-hmn
   route-map rm-ncn-w003 permit 20 set ip next-hop 10.254.0.9
   route-map rm-ncn-w003 permit 30 match ip address pl-can
   route-map rm-ncn-w003 permit 30 set ip next-hop 10.103.8.9
   route-map rm-ncn-w004 permit 10 match ip address pl-nmn
   route-map rm-ncn-w004 permit 10 set ip next-hop 10.252.0.10
   route-map rm-ncn-w004 permit 20 match ip address pl-hmn
   route-map rm-ncn-w004 permit 20 set ip next-hop 10.254.0.10
   route-map rm-ncn-w004 permit 30 match ip address pl-can
   route-map rm-ncn-w004 permit 30 set ip next-hop 10.103.8.10
   route-map rm-ncn-w005 permit 10 match ip address pl-nmn
   route-map rm-ncn-w005 permit 10 set ip next-hop 10.252.0.11
   route-map rm-ncn-w005 permit 20 match ip address pl-hmn
   route-map rm-ncn-w005 permit 20 set ip next-hop 10.254.0.11
   route-map rm-ncn-w005 permit 30 match ip address pl-can
   route-map rm-ncn-w005 permit 30 set ip next-hop 10.103.8.11
   
##
## BGP configuration
##
   protocol bgp
   router bgp 65533 vrf default
   router bgp 65533 vrf default router-id 10.252.0.1 force
   router bgp 65533 vrf default maximum-paths ibgp 32
   router bgp 65533 vrf default neighbor 10.252.0.7 remote-as 65533
   router bgp 65533 vrf default neighbor 10.252.0.7 route-map rm-ncn-w001
   router bgp 65533 vrf default neighbor 10.252.0.8 remote-as 65533
   router bgp 65533 vrf default neighbor 10.252.0.8 route-map rm-ncn-w002
   router bgp 65533 vrf default neighbor 10.252.0.9 remote-as 65533
   router bgp 65533 vrf default neighbor 10.252.0.9 route-map rm-ncn-w003
   router bgp 65533 vrf default neighbor 10.252.0.10 remote-as 65533
   router bgp 65533 vrf default neighbor 10.252.0.10 route-map rm-ncn-w004
   router bgp 65533 vrf default neighbor 10.252.0.11 remote-as 65533
   router bgp 65533 vrf default neighbor 10.252.0.11 route-map rm-ncn-w005
```

- Once the IPs are updated for the route-maps and BGP neighbors you may need to restart the BGP process on the switches, you do this by running `clear ip bgp all` on the mellanox and `clear bgp *` on the Arubas.
- If the BGP peers are still not coming up you should check the Metallb.yaml config file for errors. 
