# CRAY System Management - Guides and References
> **These pages are available offline on the LiveCD** all CSM documentation can be found at `/usr/share/doc/metal`.

This repository serves to provides coherent guides for installing or upgrading a CRAY system across all its various node-types and states.

Specifically this covers:
- Cray Pre-Install Toolkit (LiveCD)
- Non-Compute Nodes
- Compute Nodes
- User Access Nodes

Beyond node types, you can also find technical information, see the following for navigating and contributing 
to this guidebook:
- [Info / Inside-Panel](000-INFO.md) Contribution and rules
- [Table of Contents](001-GUIDES.md) Lay of the land; where information is by chapter

### Offline Documentation

The docs on a customer's LiveCD should match their reality, their install should follow the docs shipped on their liveCD.

This will report the version of your installed docs:
```bash
pit:~ # rpm -q docs-csm-install`
```

