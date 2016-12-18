#!/usr/local/sbin/container
---Basic container with tinc network.
enable_debug(nil) -- Remove this line for production.

require("module/tinc")
require("module/autoip")
ipv4_24=autoip:GetIPv4Prefix('tinc', 33)
ipv6_96=autoip:GetIPv6Prefix('tinc', 33)

--Add tinc interface
local TincInterface = tinc:AddInterface{name='tinc_testnet'}
TincInterface:LocalAddress{ipv6=ipv6_96}
TincInterface:AddIP{ipv6=ipv6_96, nat=true}
--Add default route from tinc network to host.
TincInterface:AddPrefix{ipv4='0.0.0.0/0', ipv6='::/0'}
--Route test networks to tinc.
TincInterface:AddRoute{ipv4=ipv4_24 .. '/24', ipv6=ipv6_96 .. '/96'}

function run()
	exec("iptables -t nat -A POSTROUTING ! -d " .. ipv4_24 .. "/24 -s " .. ipv4_24 .. "/24 -j MASQUERADE")
	exec("ip6tables -t nat -A POSTROUTING ! -d " .. ipv6_96 .. "/96 -s " .. ipv6_96 .. "/96 -j MASQUERADE")
	return 0
end
