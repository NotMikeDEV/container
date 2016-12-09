---Container networking support.
--	require("module/network")
--	
--	network:AddIP{ipv4='10.0.0.1', ipv6='fd00::1', nat=true}
--@module network
network = {}

---Contains an IP Address.
--@field ipv4 string IPv4 Address.
--@field ipv6 string IPv6 Address.
--@field[opt] nat boolean Enable NAT for these IP Addresses.
--@field[opt] proxyarp string ProxyARP/ProxyNDP on the specified interface on the host.
--@table address

---Add IP Address to container.
--@see address
--@param address
function network:AddIP(address)
	if not network.interfaces or not network.interfaces.uplink then network:AddInterface{name='uplink', type='ethernet', default_route=true} end
	network.interfaces.uplink:AddIP(address)
end

---Contains an IP Prefix.
--@field ipv4 string IPv4 Prefix to route.
--@field ipv6 string IPv6 Prefix to route.
--@table prefix

---Route Prefix to container.
--@see prefix
--@param prefix
function network:AddPrefix(prefix)
	if not network.interfaces or not network.interfaces.uplink then network:AddInterface{name='uplink', type='ethernet', default_route=true} end
	network.interfaces.uplink:AddPrefix(prefix)
end

---Specify Nameserver to use in container.
--Call multiple times to configure multiple servers.
--@param nameserver string Nameserver IP Address.
function network:AddNameserver(nameserver)
	if not network.nameservers then network.nameservers ={} end
	table.insert(network.nameservers, nameserver)
end

---Contains a network interface.
--@field type string Type of interface - ethernet/tinc.
--@field name string Name of interface in guest.
--@field[opt] default_route boolean Configure default route in container.
--@field[opt] tincpath string For tinc networks, the path to the tinc directory on the host.
--@table interface

---Add an interface to the container.
--@see interface
--@param interface
--@return interface
--@usage local NIC = network:AddInterface{type='ethernet', name='net0'}
--NIC:AddIP{ipv4='10.0.0.1', ipv6='fc00::1', nat=true}
--NIC:AddPrefix{ipv4='10.0.0.0/24', ipv6='fc00::/64'}
function network:AddInterface(interface)
	if not network.interfaces then network.interfaces = {} end
	---Add IP Address to interface
	--@param address table {ipv4='10.0.0.1', ipv6='fd00::1', nat=false, proxyarp='eth0'}
	function interface:AddIP(address)
		if not self.addresses then self.addresses = {} end
		self.addresses[address] = address
	end
	---Route Prefix to interface
	--@param prefix table {ipv4='10.0.0.0/8', ipv6='fd00::/16'}
	function interface:AddPrefix(prefix)
		if not self.prefixes then self.prefixes = {} end
		self.prefixes[prefix] = prefix
	end
	if not interface.type then interface.type = 'ethernet' end
	if not interface.name then interface.name = 'i' .. #network.interfaces end
	network.interfaces[interface.name] = interface
	return interface
end

function init_network_needed()
	if network.interfaces then return 1 else return 0 end
end

function init_network_host(pid)
	pid = math.floor(pid)
	debug_print('init_network_host', pid)
	if not network.interfaces then return 0 end
	write_file('/proc/sys/net/ipv4/conf/all/forwarding', '1')
	write_file('/proc/sys/net/ipv6/conf/all/forwarding', '1')
	local interface_count = 0
	for name, interface in pairs(network.interfaces) do
		interface_count = interface_count + 1
		local NIC = "c" .. string.format("%.0f", pid) .. '_' .. interface_count
		debug_print('init_network_host', "Interface " .. interface_count .. ": " .. NIC .. " > " .. interface.name .. " - " .. interface.type)
		if interface.type == "ethernet" then
			if not exec("ip link add name " .. NIC .. " type veth peer name " .. interface.name) then return 1 end
			if not exec("ifconfig " .. NIC .. " up") then return 1 end
			if not exec("ip -4 addr add 100.64.0.0/32 dev " .. NIC .. " || ip addr add 100.64.0.0/32 dev " .. NIC) then return 1 end
			if not exec("ip -6 addr add fe80::1/128 dev " .. NIC .." || ip addr add fe80::1/128 dev " .. NIC) then return 1 end
			if not exec("ip link set dev " .. interface.name .. " netns " .. string.format("%.0f", pid)) then return 1 end
			local int_v4=nil
			if interface.addresses then for _, addr in pairs(interface.addresses) do
				if addr.ipv4 then
					int_v4 = addr.ipv4
					debug_print('init_network_host', "add IPv4 address " .. addr.ipv4)
					if not exec("ip -4 route add " .. addr.ipv4 .. "/32 dev " .. NIC .. " || ip route add " .. addr.ipv4 .. "/32 dev " .. NIC) then return 1 end
					exec("iptables -t nat -D POSTROUTING -s " .. addr.ipv4 .. " -j MASQUERADE 2>/dev/null")
					if (addr.nat) then if not exec("iptables -t nat -I POSTROUTING -s " .. addr.ipv4 .. " -j MASQUERADE") then return 1 end end
					if (addr.proxyarp) then exec("arp -i " .. addr.proxyarp .. " -Ds " .. addr.ipv4 .. " " .. addr.proxyarp .. " netmask 255.255.255.255 pub") end
				end
				if addr.ipv6 then
					debug_print('init_network_host', "add IPv6 address " .. addr.ipv6)
					if not exec("ip -6 route add " .. addr.ipv6 .. "/128 dev " .. NIC .. " || ip route add " .. addr.ipv6 .. "/128 dev " .. NIC) then return 1 end
					exec("ip6tables -t nat -D POSTROUTING -s " .. addr.ipv6 .. " -j MASQUERADE 2>/dev/null")
					if (addr.nat) then if not exec("ip6tables -t nat -I POSTROUTING -s " .. addr.ipv6 .. " -j MASQUERADE") then return 1 end end
					if (addr.proxyarp) then exec("ip -6 neigh add proxy " .. addr.ipv6 .. " dev " .. addr.proxyarp .. " || ip neigh add proxy " .. addr.ipv6 .. " dev " .. addr.proxyarp) end
				end
			end end
			if interface.prefixes then for _, prefix in pairs(interface.prefixes) do
				if prefix.ipv4 then
					debug_print('init_network_host', "route IPv4 prefix " .. prefix.ipv4)
					if int_v4 then
						if not exec("ip -4 route add " .. prefix.ipv4 .. " via " .. int_v4 .. " dev " .. NIC .. " || ip route add " .. prefix.ipv4 .. " via " .. int_v4 .. " dev " .. NIC) then return 1 end
					else
						if not exec("ip -4 route add " .. prefix.ipv4 .. " dev " .. NIC .. " || ip route add " .. prefix.ipv4 .. " dev " .. NIC) then return 1 end
					end
				end
				if prefix.ipv6 then
					debug_print('init_network_host', "route IPv6 prefix " .. prefix.ipv6)
					if not exec("ip -6 route add " .. prefix.ipv6 .. " via fe80::2 dev " .. NIC .. " || ip route add " .. prefix.ipv6 .. " via fe80::2 dev " .. NIC) then return 1 end
				end
			end end
			debug_print('init_network_host', "Interface " .. interface_count)
		end
		if interface.type == "tinc" then
			if not exists('/usr/sbin/tincd') then die("Tinc not installed on host.") end

			local tincpath = '.tinc/' .. interface.name .. '/'
			if not interface.tincname then interface.tincname = interface.name end
			exec("mkdir -p ".. tincpath .. 'hosts')

			if not interface.tincport then interface.tincport = bit32.bxor(pid, 0xFFFF) end

			local hostconfig = exec("cat " .. tincpath .. "hosts/" .. interface.tincname .. "|grep -v 'Subnet'", true)

			debug_print('init_network_host', "Generating tinc config on port " .. interface.tincport)
			local tinc_conf = "Name = " .. interface.tincname .. "\n"
			tinc_conf = tinc_conf .. "Interface = " .. interface.name .. "\n"
			tinc_conf = tinc_conf .. "Port = " .. interface.tincport .. "\n"
			debug_print('init_network_host', "Searching connectable hosts.")
			if interface.tincpath then tinc_conf = tinc_conf .. exec("cd " .. interface.tincpath .. "/hosts;for host in `grep -l 'Address' *`; do echo ConnectTo = $host; cp $host "  .. base_path .. ".tinc/" .. interface.name .. "/hosts; done", true) end
			write_file(tincpath .. 'tinc.conf', tinc_conf)

			if interface.addresses then for _, addr in pairs(interface.addresses) do
				if addr.ipv4 then
					debug_print('init_network_host', "tinc route IPv4 address " .. addr.ipv4)
					hostconfig = hostconfig .. "Subnet=" .. addr.ipv4 .."/32\n"
				end
				if addr.ipv6 then
					debug_print('init_network_host', "tinc route IPv6 address " .. addr.ipv6)
					hostconfig = hostconfig .. "Subnet=" .. addr.ipv6 .."/128\n"
				end
			end end
			if interface.prefixes then for _, prefix in pairs(interface.prefixes) do
				if prefix.ipv4 then
					debug_print('init_network_host', "tinc route IPv4 prefix " .. prefix.ipv4)
					hostconfig = hostconfig .. "Subnet=" .. prefix.ipv4 .."\n"
				end
				if prefix.ipv6 then
					debug_print('init_network_host', "tinc route IPv6 prefix " .. prefix.ipv6)
					hostconfig = hostconfig .. "Subnet=" .. prefix.ipv6 .."\n"
				end
			end end

			debug_print('init_network_host', "Write tinc config.")
			write_file(tincpath .. 'hosts/' .. interface.tincname, hostconfig)
			
			if not exists(tincpath .. 'rsa_key.priv') then
				debug_print('init_network_host', "Generating tinc keys.")
				exec("echo | tincd -K -c " .. tincpath)
			end

			if interface.tincpath then
				debug_print('init_network_host', "Copy config to host.")
				exec('cp '.. tincpath .. 'hosts/' .. interface.tincname .. ' ' .. interface.tincpath .. '/hosts')
			end

			debug_print('init_network_host', "Starting tinc.")
			exec("tincd -k -c " .. tincpath .. " >/dev/null 2>&1")
			if not exec("tincd -D -c " .. tincpath .. " 2>/dev/null &") then return 1 end

			debug_print('init_network_host', "Waiting for interface.")
			local x = os.time()
			while os.difftime(os.time(), x) < 10 and not exists("/proc/sys/net/ipv4/conf/" .. interface.name) do if not exec("sleep 0.1") then return 1 end end
			
			if not exec("ip link set dev " .. interface.name .. " netns " .. string.format("%.0f", pid)) then return 1 end
		end
	end
	debug_print('init_network_host', "return 0")
	return 0
end

function init_network_child()
	debug_print('init_network_child', 'EXEC')
	if not network.interfaces then return 0 end
	exec_or_die("ifconfig lo up")
	for name, interface in pairs(network.interfaces) do
		debug_print('init_network_child', "Interface " .. interface.name .. " - " .. interface.type)
		exec_or_die("ifconfig " .. interface.name .. " up")
		if interface.default_route then
			exec_or_die("ip -4 route add 100.64.0.0/32 dev " .. interface.name)
			exec_or_die("ip -4 route add default dev " .. interface.name .. " via 100.64.0.0")
			exec_or_die("ip -6 route add default dev " .. interface.name .. " via fe80::1")
		end
		exec_or_die("ip -6 addr add fe80::2 dev " .. interface.name)
		if interface.addresses then for _, addr in pairs(interface.addresses) do
			if addr.ipv4 then
				debug_print('init_network_child', "add IPv4 address " .. addr.ipv4)
				exec_or_die("ip -4 addr add " .. addr.ipv4 .. " dev " .. interface.name)
			end
			if addr.ipv6 then
				debug_print('init_network_child', "add IPv6 address " .. addr.ipv6)
				exec_or_die("ip -6 addr add " .. addr.ipv6 .. " dev " .. interface.name)
			end
		end end
		if interface.prefixes then
			write_file('/proc/sys/net/ipv4/conf/all/forwarding', '1')
			write_file('/proc/sys/net/ipv6/conf/all/forwarding', '1')
		end
	end
	debug_print('init_network_child', "return 0")
	return 0
end

function apply_config()
	if network.nameservers then
		debug_print('init_network_child', "Write Nameservers to /etc/resolv.conf")
		local resolvconf=""
		for _, nameserver in pairs(network.nameservers) do
			resolvconf = resolvconf .. "nameserver " .. nameserver .. "\n"
		end
		write_file('./etc/resolv.conf', resolvconf)
	end
	return 0
end