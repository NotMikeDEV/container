# NAT64 Gateway.
```lua
require("templates/nat64")
```
The only parameters this module takes are an IPv4 address, and the prefix to use for NAT64.
The IPv4 address is used as a source address to route traffic to the host, it is NATed again from there and therefore does not need to be routable.
```lua
require("templates/nat64")

nat64.ipv4="100.64.64.64"
nat64.prefix="64:ff9b::/96"
```
## DNS64
If you require DNS64 to route traffic to your NAT64 then add an IPv6 Address and use the bind module to provide DNS64.
```lua
require("templates/bind")
require("templates/nat64")

request_IP("fc00::53")
nat64.ipv4="100.64.64.64"
nat64.prefix="64:ff9b::/96"
bind.nat64_prefix = nat64.prefix
```
## Side effects of loading module
The nat64 module overrides network configuration and forces network isolation to be enabled.