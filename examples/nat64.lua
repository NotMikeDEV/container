#!/usr/sbin/container
ipv4="100.64.64.64"
ipv6="2001:4860:4860::8888" -- if it goes down you get normal DNS from google, go on tell me that's a bad idea...
prefix="64:ff9b::/96"

function install_container()
	install_package("tayga")
	install_package("bind9")
end

function run()
	exec("tayga")
	exec("named")
	exec("iptables -t nat -A POSTROUTING -j MASQUERADE")
	exec("ifconfig nat64 " .. ipv4 .. " up")
	exec("ip -4 route add 100.100.0.0/16 dev nat64")
	exec("ip -6 route add " .. prefix .. " dev nat64")
	while true do exec("sleep 3") end
	return 0
end

request_IP(ipv4, {nat=true})
request_IP(ipv6, {nat=true})
request_Route(prefix)

filesystem['/var/cache/bind'] = { type="tmpfs", size="128M" }
config_files['/proc/sys/net/ipv4/conf/all/forwarding']='1'
config_files['/proc/sys/net/ipv6/conf/all/forwarding']='1'
config_files['/etc/tayga.conf'] = [[
tun-device nat64
ipv4-addr ]] .. ipv4 .. [[

prefix ]] .. prefix .. [[

dynamic-pool 100.100.0.0/16
data-dir /tmp
]]
config_files['/etc/bind/named.conf'] = [[
options {
	directory "/var/cache/bind";

	auth-nxdomain no;
	listen-on-v6 { any; };
	allow-query {0.0.0.0/0;::/0;};
	dns64 ]] .. prefix .. [[ {
			break-dnssec yes;
	};
};
]]