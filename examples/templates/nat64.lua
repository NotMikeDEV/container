#!/usr/sbin/container

nat64={}
nat64.ipv4="100.64.64.64"
nat64.prefix="64:ff9b::/96"

function install_container()
	install_package("tayga")
	return 0
end

function run()
	exec("tayga")
	exec("iptables -t nat -A POSTROUTING -j MASQUERADE")
	exec("ifconfig nat64 " .. nat64.ipv4 .. " up")
	exec("ip addr add " .. nat64.ipv4 .. " dev uplink")
	exec("ip -4 route add 100.100.0.0/16 dev nat64")
	exec("ip -6 route add " .. nat64.prefix .. " dev nat64")
	return 0
end

function init_network_needed()
	return 1
end

function init_network_host(pid)
	exec("ip -4 route add " .. nat64.ipv4 .. "/32 dev c" .. string.format("%.0f", pid))
	exec("iptables -t nat -D POSTROUTING -s " .. nat64.ipv4 .. "/32 -j MASQUERADE 2>/dev/null")
	exec("iptables -t nat -I POSTROUTING -s " .. nat64.ipv4 .. "/32 -j MASQUERADE")
	exec("ip -6 route add " .. nat64.prefix .. " via fe80::2 dev c" .. string.format("%.0f", pid))
	return 0
end

function apply_config()
	write_file('/etc/tayga.conf', [[
tun-device nat64
ipv4-addr ]] .. nat64.ipv4 .. [[

prefix ]] .. nat64.prefix .. [[

dynamic-pool 100.100.0.0/16
data-dir /tmp
]] )
	return 0
end

config_files['/proc/sys/net/ipv4/conf/all/forwarding']='1'
config_files['/proc/sys/net/ipv6/conf/all/forwarding']='1'
