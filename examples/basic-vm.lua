#!/usr/local/sbin/container
---Basic container with own network.
require("module/network")
require("module/sshd")

--Add NATED IPv4 and IPv6
network:AddIP{ipv4='100.99.98.1', ipv6='fd00::1', nat=true}

--Set SSH root password.
sshd:SetRootPassword("securepasswordxkcd")

--Make /root persistent.
Mount{ path='/root', type="map", source="root" }
