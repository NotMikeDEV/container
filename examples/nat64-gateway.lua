#!/usr/local/sbin/container
---Basic NAT64/DNS64 Gateway.
enable_debug(nil) -- Remove this line for production.

require("module/network")
require("module/nat64")
require("module/bind")

--Add NATED IPv4 and IPv6
nat64:SetNAT64{ipv4='100.99.98.64', prefix='fd64::/96'}
bind.nat64_prefix = nat64.prefix
