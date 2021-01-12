# Application Node Config

This page provides directions on constructing the `application_node_config.yaml` file. This file controls how the `csi config init` command finds and treats applications nodes discovered the `hmn_connections.json` file when building the SLS Input file. 

This file is manually created and follows this format:
```yaml
---
# Additional application node prefixes
prefixes:
  - gateway
  - visualization

# HSM Subroles
prefix_hsm_subroles:
  gateway: Gateway
  vn: Visualization

# Application Node alias
aliases:  
  x3113c0s23b0n0: ["gateway-01"]
  x3114c0s23b0n0: ["visualization-02"]
```

The following application node configuration does not add any additional prefixes, HSM subroles, or aliases: 
```yaml
# Additional application node prefixes
prefixes: [] 

# HSM Subroles
prefix_hsm_subroles: {}

# Application Node alias
aliases: {}  
```

#### Requirements
For this you will need:
- The `hmn_connections.json` file for your system

#### Background
__What is a source name?__

Example entry from the `hmn_connections.json` file. The source name is the `Source` field, and this name of the device that is being connected to the HMN network. From this source name the `csi config init` command can infer the type of hardware that is connected to the HMN network (Node, PDU, HSN Switch, etc...).
```json
{
    "Source": "uan01",
    "SourceRack": "x3000",
    "SourceLocation": "u19",
    "DestinationRack": "x3000",
    "DestinationLocation": "u14",
    "DestinationPort": "j37"
}
```

#### Directions
1. __Add additional Application node Prefixes__

    The `prefixes` field is an array of strings, that augments the list of source name prefixes that are treated as application nodes. By default `csi config init` only looks for application nodes that have source names that start with `uan`, `gn`, and `ln`. If your system contains application nodes that fall outside of those source name prefixes you will need to add additional prefixes to `application_node_config.yaml`. These additional prefixes will used in addition to the default prefixes. 

    Note: When `csi config init` is case insensitive check when checking if a source name contains an application node prefix. 

    To add an additional prefix append a new string element to the `prefixes` array:
    ```yaml
    ---
    prefixes: # Additional application node prefixes
    - gateway
    - vn
    - login # New prefix. Match source names that start with "login", such as login01 
    ```

2. __Add HSM Subroles for Application node prefixes__

    The `prefix_hsm_subroles` field mapping application node prefix (string) to the applicable Hardware State Manager (HSM) Subrole (string) for the application nodes.

    By default the `csi config init` command will use the following subroles for application nodes:

     Prefix | HSM Subrole 
     ------ | ----------- 
     uan    | UAN         
     gn     | Gateway     
     ln     | Login       

    To add additional HSM subrole for a given prefix add a new mapping under the `prefix_hsm_subroles` field. Where the key is the application node prefix and the value is the HSM subrole.
    ```yaml
    ---
    prefix_hsm_subroles:
    gateway: Gateway
    vn: Visualization
    login: Login # Application nodes that have the non-default prefix "login" are assigned the HSM subrole "Login"
    ```

3. __Add Application node aliases__
    The `aliases` field is an map of xnames (strings) to an array of aliases (strings).

    By default the `csi config init` command does set the `ExtraProperties.Alias` field for application nodes in the SLS input file. 

    Instead of manually adding the application node alias as described after the system is installed [in this procedure](306-SLS-ADD-UAN-ALIAS.md) the application node aliases can be included when the SLS Input file is built.

    To add additional application node aliases add a new mapping under the `aliases` field. Where the key is the xname of the application node, and the value is an array of aliases (strings).
    ```yaml
    ---
    aliases: # Application Node alias 
    x3113c0s23b0n0: ["gateway-01"]
    x3114c0s23b0n0: ["visualization-02"]
    x3115c0s23b0n0: ["login-01"] # Added alias for the login application node with the xname x3115c0s23b0n0
    ```
