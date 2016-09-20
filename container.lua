function exec(cmd)
	--print ("Exec: " .. cmd)
	ret = os.execute(cmd)
	return ret
end

function install_container()
end

function build()
	if isFile("/var/cache/debian.cache") then
		print("Installing debian from cache...")
		exec("tar -jxf /var/cache/debian.cache")
	else
		print("Installing debian...")
		exec("debootstrap  --include=iproute2,net-tools stable . http://http.debian.net/debian")
		if isFile("etc/debian_version") then
			print("Creating cache...")
			exec("tar -jcf /var/cache/debian.cache *")
		end
	end
	print("Updating...")
	exec("chroot . apt-get update; chroot . apt-get -y dist-upgrade")
	print("Debian Installed.")
	old_exec = exec
	exec = function (cmd) return old_exec("chroot . sh -c '" .. cmd .. "'") end
	install_container()
	exec = old_exec
	return 0
end

function need_build()
	if not isFile(base_path .. ".filesystem/bin") then return 1 end
	return 0
end

function install_package(pack)
	exec("RUNLEVEL=1 apt-get install -y " .. pack)
end

network = nil

function IP_family(ip)
	--return 4
    -- reject invalid
	if ip == nil or type(ip) ~= "string" then
		return nil
	end

	-- try parsing IPv4
    local chunks = ip:match("(%d+)%.(%d+)%.(%d+)%.(%d+)")
    if chunks then
		-- return IPv4
        return 4
    end

    -- try parsing IPv6
    local blah, chunks = ip:gsub("[%a%d]+%:?", "")
    if chunks >= 1 and ip:find(":") then
		-- return IPv6
        return 6
    end
	return nil
end

function request_IP(address, flags)
	if not flags then flags = {} end
	network = {next=network, address=address, flags=flags}
end

function request_Route(subnet, flags)
	if not flags then flags = {} end
	network = {next=network, route=subnet, flags=flags}
end

function init_network_needed()
	if network == nill then return 0 else return 1 end
end

function init_network_host(pid)
	exec("ip link add name c" .. string.format("%.0f", pid) .. " type veth peer name uplink")
	exec("ifconfig c" .. string.format("%.0f", pid) .. " up")
	exec("ip -6 addr add fe80::1/128 dev c" .. string.format("%.0f", pid))
	exec("ip -4 addr add 100.64.0.0/32 dev c" .. string.format("%.0f", pid))
	exec("ip link set dev uplink netns " .. string.format("%.0f", pid))
	local addr = network;
	while addr do
		if (addr.address) then
			if IP_family(addr.address) == 4 then
				exec("ip -4 route add " .. addr.address .. "/32 dev c" .. string.format("%.0f", pid))
				exec("iptables -t nat -D POSTROUTING -s " .. addr.address .. " -j MASQUERADE 2>/dev/null")
				if (addr.flags.nat) then
					exec("iptables -t nat -I POSTROUTING -s " .. addr.address .. " -j MASQUERADE")
				end
				if (addr.flags.proxyarp) then
					exec("arp -i " .. addr.flags.proxyarp .. " -Ds " .. addr.address .. " " .. addr.flags.proxyarp .. " netmask 255.255.255.255 pub")
				end
			end
			if IP_family(addr.address) == 6 then
				exec("ip -6 route add " .. addr.address .. "/128 dev c" .. string.format("%.0f", pid))
				exec("ip6tables -t nat -D POSTROUTING -s " .. addr.address .. " -j MASQUERADE 2>/dev/null")
				if (addr.flags.nat) then
					exec("ip6tables -t nat -I POSTROUTING -s " .. addr.address .. " -j MASQUERADE")
				end
				if (addr.flags.proxyarp) then
					exec("ip -6 neigh add proxy " .. addr.address .. " dev " .. addr.flags.proxyarp)
				end
			end
		end
		if (addr.route) then
			if IP_family(addr.route) == 4 then
				exec("ip -4 route add " .. addr.route .. " dev c" .. string.format("%.0f", pid))
			elseif IP_family(addr.route) == 6 then
				exec("ip -6 route add " .. addr.route .. " dev c" .. string.format("%.0f", pid))
			end
		end
		addr = addr.next
	end
	return 0
end

function init_network_child()
	exec("ifconfig lo up")
	exec("ifconfig uplink up")
	exec("ip -4 route add 100.64.0.0/32 dev uplink")
	exec("ip -4 route add default dev uplink via 100.64.0.0")
	exec("ip -6 route add default dev uplink via fe80::1")
	local addr = network;
	while addr do
		if (addr.address) then
			exec("ip addr add " .. addr.address .. " dev uplink")
		end
		addr = addr.next
	end
	return 0
end

function run()
	exec("init")
	return 0
end

function shell()
	exec("bash")
	return 0
end

function exists(name)
    if type(name)~="string" then return false end
    return os.rename(name,name) and true or false
end

function isFile(name)
    if type(name)~="string" then return false end
    if not exists(name) then return false end
    local f = io.open(name)
    if f then
        f:close()
        return true
    end
    return false
end

function isDir(name)
    return (exists(name) and not isFile(name))
end

function dirname(filename)
	index = filename:match("^.*()/")
	return filename:sub(0,index)
end

filesystem = {}
filesystem["/tmp"] = { type="tmpfs", size="2G" }
filesystem["/run"] = { type="tmpfs", size="128M" }
function mount_container()
	ret = exec("mount -n -o remount --make-private / /")
	if not ret then return 1 end

	ret = exec("mkdir -p .jail && mkdir -p .filesystem && mount -n -o ro --bind .filesystem .jail")
	if not ret then return 2 end

	ret = exec("mkdir -p .jail/proc && mount -t proc proc .jail/proc")
	if not ret then return 3 end

	ret = exec("mkdir -p .jail/sys && mount -t sysfs sysfs .jail/sys")
	if not ret then return 4 end

	ret = exec("mkdir -p .jail/dev && mount -t devtmpfs udev .jail/dev")
	if not ret then return 5 end

	for target, mount in pairs(filesystem) do
		if mount['type'] == "tmpfs" then
			if not isDir(".jail" .. target) then
				exec("mkdir -p .jail" .. target)
			end
			mount_opts = "-n "
			if mount['size'] then
				mount_opts = "-n -o size=" .. mount['size'] .. " "
			end
			ret = exec("mount " .. mount_opts .. "-t tmpfs tmp" .. string.sub(tostring(mount),10) .. " .jail" .. target)
			if not ret then return 1 end
		elseif mount['type'] == "map" then
			if not isDir(".jail" .. target) then
				exec("mkdir -p .jail" .. target)
			end
			exec("mkdir -p " .. mount['path']);
			ret = exec("mount -n --bind " .. mount['path'] .. " .jail" .. target)
			if not ret then return 6 end
		end
	end
	return 0
end

function lock_container()
	ret = exec("mount -n -o remount,ro --bind / /")
	if not ret then return 1 end
	return 0
end

config_files = {}
function apply_config()
	for target, content in pairs(config_files) do
		exec("mkdir -p " .. dirname(target))
		file = io.open(target, "w")
		if not file then return 1 end
		io.output(file)
		io.write(content)
		io.close(file)
	end
	return 0
end
