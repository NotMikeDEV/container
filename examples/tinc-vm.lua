#!/usr/local/sbin/container
---Basic container with tinc network.
require("module/network")
require("module/sshd")

--Add tinc interface
local ExtraInterface = network:AddInterface{name='test', type='tinc', default_route=true, tincpath='../.tinc-router.lua/tinc/tinc_testnet'}
--Assign IP Addresses.
ExtraInterface:AddIP{ipv4='100.100.0.2', ipv6='fcfc::2'}

sshd:SetRootPassword("password")

Mount{path="/root", type="map", source="root"}

