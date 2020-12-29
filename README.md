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

### Review and Contribution

Anyone with Git access to this repo may feel free to submit changes for review, tagging to the relevant JIRA(s) (if necessary).

All changes undergo a review process, this governance is up to the reviewers' own discrestions. The review serves to keep core contributors on the "same page" while maintaining coherency throughout the doc.

