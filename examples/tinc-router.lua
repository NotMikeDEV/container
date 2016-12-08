#!/usr/local/sbin/container
---Basic container with tinc network.
require("module/tinc")

--Add tinc interface
local TincInterface = tinc:AddInterface{name='tinc_testnet'}
TincInterface:LocalAddress{ipv6='fd00::123'}
TincInterface:AddIP{ipv6='fd00::123', nat=true}
--Add default route from tinc network to host.
TincInterface:AddPrefix{ipv4='0.0.0.0/0', ipv6='::/0'}
--Route test networks to tinc.
TincInterface:AddRoute{ipv4='100.100.0.0/16', ipv6='fcfc::/64'}

function run()
	exec("iptables -t nat -A POSTROUTING ! -d 100.100.0.0/16 -s 100.100.0.0/16 -j MASQUERADE")
	exec("ip6tables -t nat -A POSTROUTING ! -d fcfc::/64 -s fcfc::/64 -j MASQUERADE")
	return 0
end
