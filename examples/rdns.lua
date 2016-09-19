#!/usr/sbin/container

function install_container()
	install_package("unbound")
end

function run()
	os.execute("unbound -d")
	return 0
end

request_IP("10.0.0.53")

request_IP("2001:470:3922::1:53")

filesystem['/var/lib/unbound/'] = { type="map", path="data" }
config_files['/etc/unbound/unbound.conf.d/network.conf'] = [[
server:
	interface: ::0
	interface: 0.0.0.0
	access-control: 0.0.0.0/0 allow
	access-control: ::0/0 allow
]]
