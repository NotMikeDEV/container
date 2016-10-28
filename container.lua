math.randomseed(os.time() + (os.clock()*1000000))

function exec(cmd)
	if debug_enabled or debug_exec then print('exec("' .. cmd .. '")') end
	local ret = os.execute(cmd)
	retval = ret
	if retval == nil then retval = 'nil' end
	if debug_enabled or debug_exec then print('Returned', retval) end
	return ret
end

function exec_or_die(cmd)
	local ret = exec(cmd)
	if not ret then die("Error Executing " .. cmd) end
	return ret
end

function die(reason)
	print(reason .. "\r\n")
	os.exit(1)
end

function install_container()
	if debug_enabled then print("install_container()") end
	return 0
end

function build()
	if debug_enabled then print("build()") end
	if not isFile("/var/cache/debian.cache") then
		print("Building debian cache...")
		local f = assert(io.popen("uname -m", 'r'))
		local arch = assert(f:read('*a'))
		f:close()
		if string.find(arch, "x86_64") then arch = "amd64" end
		arch = string.gsub(arch, "\n", "")
		mkdir("../.debootstrap")
		chdir("../.debootstrap")
		exec_or_die("debootstrap  --include=iproute2,net-tools stable . http://ftp.se.debian.org/debian")
		if isFile("etc/debian_version") then
			print("Saving cache...")
			exec_or_die("tar --exclude='dev' --exclude='sys' --exclude='proc' -jcf /var/cache/debian.cache *")
		end
		chdir("../.jail")
		exec_or_die("rm -rf ../.debootstrap")
	end
	print("Installing debian from cache...")
	exec_or_die("tar --overwrite -jxf /var/cache/debian.cache")
	print("Updating...")
	exec_or_die("chroot . apt-get update; chroot . apt-get -y dist-upgrade")
	print("Debian Installed.")
	old_exec = exec
	exec = function (cmd) return old_exec("chroot . sh -c '" .. cmd .. "'") end
	local ret = install_container()
	exec = old_exec
	write_file("../.built", "")
	return ret
end

function need_build()
	if not isFile(base_path .. ".built") then return 1 end
	return 0
end

function install_package(pack)
	if debug_enabled then print('install_package("' .. pack .. '")') end
	exec_or_die("RUNLEVEL=1 apt-get install -y --force-yes " .. pack)
	return 0
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
	if debug_enabled then print('request_IP("' .. address .. '", ...)') end
	if not flags then flags = {} end
	network = {next=network, address=address, flags=flags}
end

function request_Route(subnet, flags)
	if debug_enabled then print('request_Route("' .. subnet .. '", ...)') end
	if not flags then flags = {} end
	network = {next=network, route=subnet, flags=flags}
end

function init_network_needed()
	if network == nill then return 0 else return 1 end
end

function init_network_host(pid)
	if debug_enabled then print("init_network_host()") end
	exec_or_die("ip link add name c" .. string.format("%.0f", pid) .. " type veth peer name uplink")
	exec_or_die("ifconfig c" .. string.format("%.0f", pid) .. " up")
	exec_or_die("ip -6 addr add fe80::1/128 dev c" .. string.format("%.0f", pid))
	exec_or_die("ip -4 addr add 100.64.0.0/32 dev c" .. string.format("%.0f", pid))
	exec_or_die("ip link set dev uplink netns " .. string.format("%.0f", pid))
	local addr = network;
	while addr do
		if (addr.address) then
			if debug_enabled then print("add address " .. addr.address) end
			if IP_family(addr.address) == 4 then
				exec_or_die("ip -4 route add " .. addr.address .. "/32 dev c" .. string.format("%.0f", pid))
				exec("iptables -t nat -D POSTROUTING -s " .. addr.address .. " -j MASQUERADE 2>/dev/null")
				if (addr.flags.nat) then
					exec_or_die("iptables -t nat -I POSTROUTING -s " .. addr.address .. " -j MASQUERADE")
				end
				if (addr.flags.proxyarp) then
					exec("arp -i " .. addr.flags.proxyarp .. " -Ds " .. addr.address .. " " .. addr.flags.proxyarp .. " netmask 255.255.255.255 pub")
				end
			end
			if IP_family(addr.address) == 6 then
				exec_or_die("ip -6 route add " .. addr.address .. "/128 dev c" .. string.format("%.0f", pid))
				exec("ip6tables -t nat -D POSTROUTING -s " .. addr.address .. " -j MASQUERADE 2>/dev/null")
				if (addr.flags.nat) then
					exec_or_die("ip6tables -t nat -I POSTROUTING -s " .. addr.address .. " -j MASQUERADE")
				end
				if (addr.flags.proxyarp) then
					exec("ip -6 neigh add proxy " .. addr.address .. " dev " .. addr.flags.proxyarp)
				end
			end
		end
		if (addr.route) then
			if debug_enabled then print("add route ".. addr.route) end
			if IP_family(addr.route) == 4 then
				exec_or_die("ip -4 route add " .. addr.route .. " dev c" .. string.format("%.0f", pid))
			elseif IP_family(addr.route) == 6 then
				exec_or_die("ip -6 route add " .. addr.route .. " via fe80::2 dev c" .. string.format("%.0f", pid))
			end
		end
		addr = addr.next
	end
	if debug_enabled then print("return 0") end
	return 0
end

function init_network_child()
	if debug_enabled then print("init_network_child()") end
	exec_or_die("ifconfig lo up")
	exec_or_die("ifconfig uplink up")
	exec_or_die("ip -4 route add 100.64.0.0/32 dev uplink")
	exec_or_die("ip -4 route add default dev uplink via 100.64.0.0")
	exec_or_die("ip -6 route add default dev uplink via fe80::1")
	exec_or_die("ip addr add fe80::2 dev uplink")
	local addr = network;
	while addr do
		if (addr.address) then
			exec_or_die("ip addr add " .. addr.address .. " dev uplink")
		end
		addr = addr.next
	end
	if debug_enabled then print("return 0") end
	return 0
end

function run()
	print("Launching container.")
	return 0
end

function shell()
	print("Launching shell.")
	exec("sh")
	return 0
end

function pairsByKeys (t, f)
	local a = {}
	for n in pairs(t) do table.insert(a, n) end
	table.sort(a, f)
	local i = 0      -- iterator variable
	local iter = function ()   -- iterator function
		i = i + 1
		if a[i] == nil then return nil
		else return a[i], t[a[i]]
		end
	end
	return iter
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
	if debug_enabled then print('mount_container()') end

	exec_or_die("mount -n -o remount --make-private / /")
	exec_or_die("mkdir -p .jail && mkdir -p .filesystem && mount -n -o rw --bind .filesystem .jail")
	exec_or_die("mkdir -p .jail/proc && mount -t proc proc .jail/proc")
	exec_or_die("mkdir -p .jail/sys && mount --bind /sys .jail/sys")
	exec_or_die("mkdir -p .jail/dev && mount -t devtmpfs udev .jail/dev")
	for target, mount in pairsByKeys(filesystem) do
		if mount['type'] == "tmpfs" then
			if not isDir(".jail" .. target) then
				exec("mkdir -p .jail" .. target)
			end
			mount_opts = "-n "
			if mount['size'] then
				mount_opts = "-n -o size=" .. mount['size'] .. " "
			end
			exec_or_die("mount " .. mount_opts .. "-t tmpfs tmp" .. string.sub(tostring(mount),10) .. " .jail" .. target)
		elseif mount['type'] == "map" then
			if not isDir(".jail" .. target) then
				exec("mkdir -p .jail" .. target)
			end
			exec("mkdir -p " .. mount['path']);
			exec_or_die("mount -n --bind " .. mount['path'] .. " .jail" .. target)
		end
	end
	return 0
end

function lock_container()
	if debug_enabled then print('lock_container()') end

	exec_or_die("mount -n -o remount,ro --bind / /")
	return 0
end

function read_file(filename)
	if debug_enabled then print('read_file("' .. filename .. '")') end
	local contents = ""
	file = io.open(filename, "r")
	if not file then return nil end
	io.input(file)
	while true do
		local block = io.read(1024*1024)
		if not block then break end
		contents = contents .. block
    end
	io.close(file)
	return contents
end

function write_file(filename, contents)
	if debug_enabled then print('write_file("' .. filename .. '", ... )') end
	file = io.open(filename, "w")
	if not file then return 1 end
	io.output(file)
	io.write(contents)
	io.close(file)
	return 0
end

config_files = {}
function apply_config()
	if debug_enabled then print('apply_config()') end
	for target, content in pairs(config_files) do
		exec("mkdir -p " .. dirname(target))
		write_file(target, content)
	end
	return 0
end

function table.clone(org)
	local new = {}
	for name, value in pairs(org) do
		new[name] = value
	end
	return new
end

function prepend_functions(target, source, modulename)
	for name, sourcefunc in pairs(source) do
		if type(source[name]) == "function" and type(target[name]) == "function" and source[name] ~= target[name] then
			local previousfunc = target[name]
			target[name] = function (...)
				local ret = sourcefunc(...)
				if ret ~= 0 then return ret end
				if debug_enabled then print("Calling " .. name .. "() from " .. modulename) end
				ret = previousfunc(...)
				if debug_enabled then print(name .. "() from " .. modulename .. " returned " .. ret) end
				return ret
			end
		end
	end
end

-- casts a spell on the require() function to give it magic function inheritance
include = require
function require(modulename)
	if debug_enabled then print('require("' .. modulename .. '")') end
	include(modulename)
	FIX_ENVIRONMENT(modulename)
end

local DEFAULT_ENVIRONMENT = table.clone(_ENV)
function FIX_ENVIRONMENT(modulename)
	if not modulename then modulename = 'container' end
	prepend_functions(_ENV, DEFAULT_ENVIRONMENT, modulename)
	DEFAULT_ENVIRONMENT = table.clone(_ENV)
	return 0
end
