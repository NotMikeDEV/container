---Global API functions.
--@topic Global_Environment

math.randomseed(os.time() + (os.clock()*1000000))

---Execute command.
--@param command string.
--@param capture_output boolean return stdout instead of true/false.
--@return boolean success true/false.
function exec(command, capture_output)
	debug_print('exec', command)
	--capture output
	if capture_output then
		local f = assert(io.popen(command, 'r'))
		local output = f:read('*a')
		f:close()
		debug_print('exec_ret', output)
		return output
	end
	--execute normally
	local ret = os.execute(command)
	retval = ret
	debug_print('exec_ret', retval)
	return ret
end

---Execute command, terminate on failure.
--@param command string.
--@return boolean true.
function exec_or_die(command)
	debug_print('exec_or_die', command)
	local ret = exec(command)
	if not ret then die("Error Executing " .. command) end
	return ret
end

---Install package using apt.
--@param name string.
function install_package(name)
	debug_print('install_package', 'install_package("' .. name .. '")')
	exec_or_die("RUNLEVEL=1 DEBIAN_FRONTEND=noninteractive apt-get install -qy --force-yes " .. name)
	return 0
end

---Terminate execution.
--@param reason string.
function die(reason)
	print(reason .. "\r\n")
	os.exit(1)
end

local filesystems = {}

---Mount point.
--@param type string Type of mount, "map" or "tmpfs".
--@param path string Target path in container.
--@param source string For type 'map', specifies the source directory on the host.
--@param size string For type 'tmpfs', specifies the size of the mount.
--@table mount

---Mount Filesystem.
--@see mount
--@param mount mount
function Mount(mount)
	filesystems[mount.path] = mount
	return 0
end

Mount{ path="/tmp", type="tmpfs", size="2G" }
Mount{ path="/run", type="tmpfs", size="128M" }

include = require
---Load external file
function require(modulename)
	debug_print('require', modulename)
	include(modulename)
	FIX_ENVIRONMENT(modulename)
end

---Read file contents.
--@param filename string.
--@return string
function read_file(filename)
	debug_print('read_file', filename)
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

---Write to a file.
--@param filename string.
--@param contents string.
--@return 0
function write_file(filename, contents)
	debug_print('write_file', filename .. "\n" .. contents)
	file = io.open(filename, "w")
	if not file then return 1 end
	io.output(file)
	io.write(contents)
	io.close(file)
	return 0
end

---Check if file exists.
--@param name string.
--@return boolean
function exists(name)
	if type(name)~="string" then return false end
	return os.rename(name,name) and true or false
end

---Check if file is a file.
--@param name string.
--@return boolean
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

---Check if file is a directory.
--@param name string.
--@return boolean
function isDir(name)
	return (exists(name) and not isFile(name))
end

---Get the path to a file.
--@param name string.
--@return boolean
function dirname(name)
	index = name:match("^.*()/")
	return name:sub(0,index)
end

local debug_table=nil
---Enable debugging.
--@param filter string Function to debug, nil for all.
function enable_debug(filter)
	if not debug_table then debug_table = {} end
	if not filter then filter = 'all' end
	debug_table[filter] = true
end

function debug_print(filter, ...)
	if debug_table and ( debug_table[filter] or debug_table['all'] ) then
		print(filter, ...)
	end
end

---Callbacks.
--Define these functions to define behaviour that should be executed at the appropriate time.
--If the same function is defined in multiple files then all will be executed.
--
--Callbacks should always return 0 on success.
--@section callbacks

---Callback executed to install container applications.
function install_container()
	debug_print("install_container", 'EXEC')
	return 0
end

---Callback executed to launch container applications.
function run()
	debug_print("run", 'EXEC')
	return 0
end

---Callback launched as daemon when container has launched.
function background()
	return 0
end

local nameservers=nil
---Callback executed to write configuration files.
function apply_config()
	debug_print('apply_config', 'configure nameservers')
	if not nameservers then
		local file = io.open("/etc/resolv.conf", "r")
		if file then
			nameservers={}
			io.input(file)
			local line = io.read("*line")
			while line do
				local server = line:match("nameserver%s*(%g*)")
				if server == "::1" then server = "2001:4860:4860::8844" end
				if server == "127.0.0.1" then server = "8.8.4.4" end
				if server then table.insert(nameservers, server) end
				line = io.read("*line")
			end
		io.close(file)
		end
	end

	if nameservers then
		local resolvconf = ""
		for _,server in pairs(nameservers) do
			resolvconf = resolvconf .. "nameserver " .. server .. "\n"
		end
		if resolvconf then write_file("etc/resolv.conf", resolvconf) end
	end
	return 0
end

---Callback executed to test if container neets an isolated network
--@return 1 to initialise networking, 0 otherwise
function init_network_needed()
	return 0
end

---Callback executed to initialise host networking.
--@param pid int PID of container.
function init_network_host(pid)
	debug_print("init_network_host", 'EXEC')
	return 0
end

---Callback executed to initialise child networking.
function init_network_child()
	debug_print("init_network_child", 'EXEC')
	return 0
end

function shell()
	print("Launching shell.")
	exec("sh")
	return 0
end

function need_build()
	if not isFile(base_path .. ".built") then return 1 end
	return 0
end

debian = {}
debian.mirror = "http://debian.linuxship.net/debian";
debian.arch = exec("uname -m", true)
debian.arch = string.gsub(debian.arch, "\n", "")
if debian.arch:find("x86_64") then debian.arch = "amd64" end
if debian.arch:find("i686") then debian.arch = "i386" end
debian.cache_file = "/usr/local/container/debian." .. debian.arch .. ".tar.gz";
debian.cache_URL = "http://cache.linuxship.net/debian." .. debian.arch .. ".tar.gz";

function build()
	debug_print("build", "EXEC")
	if not isFile(debian.cache_file) then
		print("Downloading debian cache...")
		local suffix = '.' .. os.time() .. "." .. math.random(10000,99999)
		exec("( wget -c -N " .. debian.cache_URL .. " -O " .. debian.cache_file .. suffix .. " && mv " .. debian.cache_file .. suffix .. " " .. debian.cache_file .. " ) || rm -f " .. debian.cache_file .. suffix)
	end
	if not isFile(debian.cache_file) then
		print("Building debian cache...")
		mkdir("../.debootstrap")
		chdir("../.debootstrap")
		exec_or_die("debootstrap  --include=iproute2,net-tools stable . " .. debian.mirror)
		if isFile("etc/debian_version") then
			print("Saving cache...")
			exec_or_die("tar --exclude='dev' --exclude='sys' --exclude='proc' -zcf ../.debian.cache *")
			exec_or_die("rm -f /var/cache/debian.cache && mv ../.debian.cache " .. debian.cache_file)
		end
		chdir("../.jail")
		exec_or_die("rm -rf ../.debootstrap")
	end
	print("Installing debian from cache...")
	exec("tar -zxf " .. debian.cache_file)
	if not isFile("etc/debian_version") then die("Error extracting debian image.") end
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

function pairsByKeys (t, f)
	local a = {}
	for n in pairs(t) do table.insert(a, n) end
	table.sort(a, f)
	local i = 0	  -- iterator variable
	local iter = function ()   -- iterator function
		i = i + 1
		if a[i] == nil then return nil
		else return a[i], t[a[i]]
		end
	end
	return iter
end

function mount_container()
	debug_print('mount_container', 'EXEC')

	exec_or_die("mkdir -p .jail && mkdir -p .filesystem && mount -n --make-rprivate --make-private -o rw --bind .filesystem .jail")
	exec_or_die("mkdir -p .jail/proc && mount -t proc proc .jail/proc")
	exec_or_die("mkdir -p .jail/sys && mount -t sysfs /sys .jail/sys")
	exec_or_die("mkdir -p .jail/dev && mount -t devtmpfs udev .jail/dev")
	exec_or_die("mkdir -p .jail/dev/pts && mount -t devpts devpts .jail/dev/pts")
	for target, mount in pairsByKeys(filesystems) do
		debug_print('mount_container', mount['type'] .. ':' .. target)
		if mount['type'] == "tmpfs" then
			if not isDir(".jail/" .. target) then
				exec("mkdir -p .jail/" .. target)
			end
			mount_opts = "-n "
			if mount['size'] then
				mount_opts = mount_opts .. "-o size=" .. mount['size'] .. " "
			end
			exec_or_die("mount " .. mount_opts .. "-t tmpfs tmp" .. string.sub(tostring(mount),10) .. " .jail/" .. target)
		elseif mount['type'] == "map" then
			if not mount['source'] then die("No source specified for " .. target) end
			if not isDir(".jail/" .. target) then
				exec("mkdir -p .jail/" .. target)
			end
			exec("mkdir -p " .. mount['source']);
			exec_or_die("mount -n --make-rprivate --make-private --bind " .. mount['source'] .. " .jail/" .. target)
		end
	end
	return 0
end

function unmount_container()
	debug_print('unmount_container', "EXEC")
	exec("umount -l -R " .. base_path ..  "/.jail 2>&1", true)
	return 0
end

function lock_container()
	debug_print('lock_container', "EXEC")

	exec_or_die("mount -n -o remount,ro --bind / /")
	return 0
end

function table.clone(org)
	local new = {}
	for name, value in pairs(org) do
		new[name] = value
	end
	return new
end

local daemons={}

function start_daemons()
	debug_print('start_daemons', daemons)
	for _, daemon in pairs(daemons) do
		if fork() == 0 then
			debug_print('start_daemons', daemon.mod)
			local ret = daemon.func();
			debug_print('start_daemons', daemon.mod .. ' returned ' .. ret)
			os.exit(0)
		end
	end
	debug_print('start_daemons', "Started.")
	return 0
end

function prepend_functions(target, source, modulename)
	debug_print('prepend_functions', modulename)
	for name, sourcefunc in pairs(source) do
		if (name == 'background' and type(target[name]) == "function") and target[name] ~= source[name] then
			debug_print('prepend_functions', modulename .. ': Daemon.')
			table.insert(daemons, {mod=modulename, func=target[name]})
			target[name]=source[name]
		elseif type(source[name]) == "function" and type(target[name]) == "function" and source[name] ~= target[name] then
			local previousfunc = target[name]
			target[name] = function (...)
				local ret = sourcefunc(...)
				if ret ~= 0 then return ret end
				debug_print(name, "Calling from " .. modulename)
				ret = previousfunc(...)
				debug_print(name, "Module " .. modulename .. " returned " .. ret)
				return ret
			end
			debug_print('prepend_functions', modulename .. ': ' .. name)
		end
	end
end

---Fix Global Functions.
--Internal function used to chain functions together.
--@param modulename string.
local DEFAULT_ENVIRONMENT = table.clone(_ENV)
function FIX_ENVIRONMENT(modulename)
	debug_print('FIX_ENVIRONMENT', modulename)
	if not modulename then modulename = 'container' end
	prepend_functions(_ENV, DEFAULT_ENVIRONMENT, modulename)
	DEFAULT_ENVIRONMENT = table.clone(_ENV)
	return 0
end

