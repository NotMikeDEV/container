---Tinc VPN Client.
--@module tinc
tinc = {}

---Add tinc VPN.
--@see network:interface
--@param interface
--@return interface
--@usage local Tinc = tinc:AddInterface{name='net0'}
--Tinc:AddIP{ipv4='10.0.0.1', ipv6='fc00::1', nat=true}
function tinc:AddInterface(interface)
	if not tinc.interfaces then tinc.interfaces = {} end
	---Add IP Address to interface.
	--@see network:address
	--@param address table {ipv4='10.0.0.1', ipv6='fd00::1', nat=false, proxyarp='eth0'}
	function interface:LocalAddress(address)
		if not self.localaddresses then self.localaddresses = {} end
		self.localaddresses[address] = address
	end
	---Add IP Address to interface.
	--@see network:address
	--@param address table {ipv4='10.0.0.1', ipv6='fd00::1', nat=false, proxyarp='eth0'}
	function interface:AddIP(address)
		if not self.addresses then self.addresses = {} end
		self.addresses[address] = address
	end
	---Advertise Prefix.
	--@see network:prefix
	--@param prefix table {ipv4='10.0.0.0/8', ipv6='fd00::/16'}
	function interface:AddPrefix(prefix)
		if not self.prefixes then self.prefixes = {} end
		self.prefixes[prefix] = prefix
	end
	---Route Prefix out of interface.
	--@see network:prefix
	--@param prefix table {ipv4='10.0.0.0/8', ipv6='fd00::/16'}
	function interface:AddRoute(prefix)
		if not self.routes then self.routes = {} end
		self.routes[prefix] = prefix
	end
	tinc.interfaces[interface.name] = interface
	return interface
end

function install_container()
	install_package("tinc")
	return 0
end

function apply_config()
	if not tinc.interfaces then return 0 end
	debug_print('apply_config', "Configuring Tinc.")
	
	local interface_count = 0
	for name, interface in pairs(tinc.interfaces) do
		interface_count = interface_count + 1
		debug_print('apply_config', "Tinc Interface " .. interface_count .. ": " .. interface.name)

		local tincpath = '/etc/tinc/' .. interface.name .. '/'
		if interface.tincpath then tincpath = interface.tincpath end
		exec("mkdir -p ".. tincpath .. 'hosts')

		if not interface.tincport then interface.tincport = math.random(40000,65535) end

		debug_print('apply_config', "Generating tinc config on port " .. interface.tincport)
		local tinc_conf = "Name = " .. interface.name .. "\n"
		tinc_conf = tinc_conf .. "Interface = " .. interface.name .. "\n"
		tinc_conf = tinc_conf .. "Port = " .. interface.tincport .. "\n"
		debug_print('apply_config', "Searching connectable hosts.")
		tinc_conf = tinc_conf .. exec("cd " .. tincpath .. "/hosts;for host in `grep -l 'Address' *`; do echo ConnectTo = $host; done", true)
		write_file(tincpath .. 'tinc.conf', tinc_conf)

		if not exists(tincpath .. 'rsa_key.priv') then
			debug_print('apply_config', "Generating tinc keys.")
			exec("echo | tincd -K -c " .. tincpath)
		end

		local hostconfig = ""
		if interface.localaddresses then for _, addr in pairs(interface.localaddresses) do
			if addr.ipv4 then
				debug_print('apply_config', "tincd IPv4 address " .. addr.ipv4)
				hostconfig = hostconfig .. "Address=" .. addr.ipv4 .." " .. interface.tincport .. "\n"
			end
			if addr.ipv6 then
				debug_print('apply_config', "tincd IPv6 address " .. addr.ipv6)
				hostconfig = hostconfig .. "Address=" .. addr.ipv6 .." " .. interface.tincport .. "\n"
			end
			if addr.hostname then
				debug_print('apply_config', "tincd hostname " .. addr.hostname)
				hostconfig = hostconfig .. "Address=" .. addr.hostname .." " .. interface.tincport .. "\n"
			end
		end end
		if interface.addresses then for _, addr in pairs(interface.addresses) do
			if addr.ipv4 then
				debug_print('apply_config', "tinc route IPv4 address " .. addr.ipv4)
				hostconfig = hostconfig .. "Subnet=" .. addr.ipv4 .."/32\n"
			end
			if addr.ipv6 then
				debug_print('apply_config', "tinc route IPv6 address " .. addr.ipv6)
				hostconfig = hostconfig .. "Subnet=" .. addr.ipv6 .."/128\n"
			end
		end end
		if interface.prefixes then for _, prefix in pairs(interface.prefixes) do
			if prefix.ipv4 then
				debug_print('apply_config', "tinc route IPv4 prefix " .. prefix.ipv4)
				hostconfig = hostconfig .. "Subnet=" .. prefix.ipv4 .."\n"
			end
			if prefix.ipv6 then
				debug_print('apply_config', "tinc route IPv6 prefix " .. prefix.ipv6)
				hostconfig = hostconfig .. "Subnet=" .. prefix.ipv6 .."\n"
			end
		end end

		debug_print('apply_config', "Write tinc config.")
		hostconfig = hostconfig .. exec("cd " .. tincpath .. "/hosts; cat " .. interface.name .. "|grep -v 'Subnet'|grep -v 'Address'", true)
		write_file(tincpath .. 'hosts/' .. interface.name, hostconfig)
	end
	return 0
end
function run()
	if not tinc.interfaces then return 0 end
	print("Starting tinc.")
	local interface_count = 0
	for name, interface in pairs(tinc.interfaces) do
		interface_count = interface_count + 1
		debug_print('run', "Tinc Interface " .. interface_count .. ": " .. interface.name)

		local tincpath = '/etc/tinc/' .. interface.name .. '/'
		if interface.tincpath then tincpath = interface.tincpath end

		debug_print('run', "Starting tinc.")
		exec("tincd -k -c " .. tincpath .. " >/dev/null 2>&1")
		if not exec("tincd -D -c " .. tincpath .. " 2>/dev/null &") then return 1 end

		debug_print('run', "Waiting for interface.")
		local x = os.time()
		while os.difftime(os.time(), x) < 10 and not exists("/proc/sys/net/ipv4/conf/" .. interface.name) do if not exec("sleep 0.1") then return 1 end end

		exec_or_die("ifconfig " .. interface.name .. " up")

		if interface.default_route then
			exec_or_die("ip -4 route add default dev " .. interface.name .. "|| ip route add 0.0.0.0/0 dev " .. interface.name)
			exec_or_die("ip -6 route add default dev " .. interface.name .. "|| ip route add ::/0 dev " .. interface.name)
		end

		if interface.addresses then for _, addr in pairs(interface.addresses) do
			if addr.ipv4 then
				debug_print('run', "add IPv4 address " .. addr.ipv4)
				exec_or_die("ip -4 addr add " .. addr.ipv4 .. " dev " .. interface.name .. " || ip addr add " .. addr.ipv4 .. " dev " .. interface.name)
			end
			if addr.ipv6 then
				debug_print('run', "add IPv6 address " .. addr.ipv6)
				exec_or_die("ip -6 addr add " .. addr.ipv6 .. " dev " .. interface.name .. " || ip addr add " .. addr.ipv6 .. " dev " .. interface.name)
			end
		end end

		if interface.routes then for _, route in pairs(interface.routes) do
			if route.ipv4 then
				debug_print('run', "add IPv4 route " .. route.ipv4)
				exec_or_die("ip -4 route add " .. route.ipv4 .. " dev " .. interface.name .. " || ip route add " .. route.ipv4 .. " dev " .. interface.name)
			end
			if route.ipv6 then
				debug_print('run', "add IPv6 route " .. route.ipv6)
				exec_or_die("ip -6 route add " .. route.ipv6 .. " dev " .. interface.name .. "|| ip route add " .. route.ipv6 .. " dev " .. interface.name)
			end
		end end

		if interface.prefixes then
			write_file('/proc/sys/net/ipv4/conf/all/forwarding', '1')
			write_file('/proc/sys/net/ipv6/conf/all/forwarding', '1')
		end
	end
	return 0
end
Mount{path='/etc/tinc', type='map', source='tinc'}