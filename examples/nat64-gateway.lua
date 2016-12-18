#!/usr/local/sbin/container
---Basic NAT64/DNS64 Gateway.
enable_debug(nil) -- Remove this line for production.

require("module/network")
require("module/nat64")
require("module/bind")
require("module/autoip")
local IPv4 = autoip:GetIPv4("nat64", 64)
local IPv6 = autoip:GetIPv6Prefix("nat64", 64)

--Add NATED IPv4 and IPv6
nat64:SetNAT64{ipv4=IPv4, prefix=IPv6 .. '/96'}
bind.nat64_prefix = nat64.prefix
network:AddIP{ipv6=IPv6, nat=true}
