---NAT64 Gateway.
--@module nat64

---NAT64 Configuration.
--@field ipv4 string IPv4 Address of gateway.
--@field prefix string IPv6 Prefix to route via NAT64.
--@field[opt] pool string IPv4 Pool to use (Auto-NATed).
--@table nat64config
nat64 = {}

if not network then die("Error: nat64 module requires network module.") end

---Set the NAT64 gateway parameters.
--@param nat64config nat64config
function nat64:SetNAT64(nat64config)
	if not nat64config.pool then nat64config.pool = "100.64.0.0/16" end
	network:AddIP{ipv4=nat64config.ipv4, nat=true}
	network:AddPrefix{ipv6=nat64config.prefix, nat=false}
	nat64 = nat64config
end

function install_container()
	install_package("tayga")
	return 0
end

function run()
	if not nat64.ipv4 or not nat64.prefix then return 0 end
	exec("tayga")
	exec("iptables -t nat -A POSTROUTING -s " .. nat64.pool .. " -j MASQUERADE")
	exec("ifconfig nat64 " .. nat64.ipv4 .. " up")
	exec("ip -4 route add " .. nat64.pool .. " dev nat64")
	exec("ip -6 route add " .. nat64.prefix .. " dev nat64")
	return 0
end

function apply_config()
	if not nat64.ipv4 or not nat64.prefix then return 0 end
	write_file('/etc/tayga.conf', [[
tun-device nat64
ipv4-addr ]] .. nat64.ipv4 .. [[

prefix ]] .. nat64.prefix .. [[

dynamic-pool ]] .. nat64.pool .. [[

data-dir /tmp
]] )
	return 0
end
