---BIND DNS server.
--	require("module/bind")
--	
--	bind:NewZone{domain='example.com', type='master', file='/path/to/example.com.db'}
--	bind:NewZone{domain='example.net', type='slave', masters={"10.0.0.2"}}
--@module bind
bind = {}

---Allow IP to query server.
--@param ip string
function bind:AllowQuery(ip)
	if not bind.allow_query then bind.allow_query = {} end
	bind.allow_query[ip] = ip
end

---Allow IP to query server.
--@param ip string
function bind:AllowRecursion(ip)
	if not bind.allow_recursion then bind.allow_recursion = {} end
	bind.allow_recursion[ip] = ip
end

---Zone file.
--@field domain string The domain name.
--@field type string 'master' or 'slave'.
--@field[opt] file string Path to zone file.
--@field[opt] masters table If type is 'slave' then a list of master servers. Example: {'172.16.0.53', 'fc00::53'}
--@table zone

---Add a new zone.
--@see zone
--@param zone zone 
function bind:NewZone(zone)
	if not zone.domain then print("bind:NewZone", "No domain specified.") os.exit(1) end
	if not zone.type then zone.type = 'master' .. zone.domain end
	if not zone.file then zone.file = '/etc/bind/zones/' .. zone.domain end

	if not bind.zones then bind.zones = {} end
	bind.zones[zone] = zone
end

function install_container()
	install_package("bind9")
	return 0
end

function run()
	print("Starting Bind.")
	exec("named")
	return 0
end

function apply_config()
	local config = {}
	config[#config+1] = 'directory "/var/cache/bind";'
	config[#config+1] = 'listen-on-v6 { any; };'
	if bind.allow_query then
		debug_print('apply_config', "Allow Query.")
		local allow_query = "allow-query {\n"
		for _, ip in pairs(bind.allow_query) do
			debug_print('apply_config', "Allow " .. ip)
			allow_query = allow_query .. ip ..";\n"
		end
		allow_query = allow_query .. "};"
		config[#config+1] = allow_query
	else
		config[#config+1] = 'allow-query {0.0.0.0/0;::/0;};'
	end

	if bind.allow_recursion then
		debug_print('apply_config', "Allow Recursion.")
		local allow_recursion = "allow-recursion {\n"
		for _, ip in pairs(bind.allow_recursion) do
			debug_print('apply_config', "Allow " .. ip)
			allow_recursion = allow_recursion .. ip ..";\n"
		end
		allow_recursion = allow_recursion .. "};"
		config[#config+1] = allow_recursion
	else
		config[#config+1] = 'allow-recursion {0.0.0.0/0;::/0;};'
	end

	if bind.nat64_prefix then
		debug_print('apply_config', "DNS64 Prefix " .. bind.nat64_prefix)
		config[#config+1] = 'dns64 ' .. bind.nat64_prefix .. "{ break-dnssec yes; };"
	end
	
	local config_options = ""
	for _, option in pairs(config) do
		config_options = config_options .. option .. "\n";
	end
	config_options = "options {\n" .. config_options .. "\n};\n"
	
	if bind.zones then for _, zone in pairs(bind.zones) do
		debug_print('apply_config', "Zone " .. zone.domain)
		config_options = config_options .. "zone \"" .. zone.domain .. "\" {\n";
		config_options = config_options .. "\ttype\t" .. zone.type .. ";\n";
		config_options = config_options .. "\tfile\t\"" .. zone.file .. "\";\n";
		if zone.masters then
			config_options = config_options .. "\tmasters {\n";
			for _,master in pairs(zone.masters) do
				debug_print('apply_config', "- Master " .. master)
				config_options = config_options .. "\t\t" .. master .. ";\n";
			end
			config_options = config_options .. "\t};\n";
		end
		config_options = config_options .. "};\n";
	end end
	write_file('/etc/bind/named.conf', config_options)
	return 0
end

Mount{path='/var/cache/bind', type="tmpfs", size="128M" }
Mount{path='/etc/bind/zones', type="map", source="zones" }
