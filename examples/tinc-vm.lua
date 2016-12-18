#!/usr/local/sbin/container
---Basic container with tinc network.
enable_debug(nil) -- Remove this line for production.

require("module/network")
require("module/sshd")
require("module/autoip")

ipv4=explode_v4(autoip:GetIPv4Prefix('tinc', 33))
ipv4[4] = 6
ipv4=implode_v4(ipv4)

ipv6=explode_v6(autoip:GetIPv6Prefix('tinc', 33))
ipv6[8] = 6
ipv6=implode_v6(ipv6)

--Add tinc interface
local ExtraInterface = network:AddInterface{name='test', type='tinc', default_route=true, tincpath='../.tinc-router.lua/tinc/tinc_testnet'}
--Assign IP Addresses.
ExtraInterface:AddIP{ipv4=ipv4, ipv6=ipv6}

sshd:SetRootPassword("password")

Mount{path="/root", type="map", source="root"}

