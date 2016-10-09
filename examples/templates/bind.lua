bind = {}

function bind:AllowRecursion(ip)
	if not bind.allow_query then bind.allow_query = {} end
	bind.allow_query[ip] = ip
end

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
		local allow_query = "allow-query {\n"
		for _, ip in pairs(bind.allow_query) do
			allow_query = allow_query .. ip ..";\n"
		end
		allow_query = allow_query .. "};"
		config[#config+1] = allow_query
	else
		config[#config+1] = 'allow-query {0.0.0.0/0;::/0;};'
	end
	if bind.nat64_prefix then
		config[#config+1] = 'dns64 ' .. bind.nat64_prefix .. "{ break-dnssec yes; };"
	end
	
	local config_options = ""
	for _, option in pairs(config) do
		config_options = config_options .. option .. "\n";
	end
	config_options = "options {\n" .. config_options .. "\n};\n"
	
	if bind.zones then for _, zone in pairs(bind.zones) do
		config_options = config_options .. "zone \"" .. zone.domain .. "\" {\n";
		config_options = config_options .. "\ttype\t" .. zone.type .. ";\n";
		config_options = config_options .. "\tfile\t\"" .. zone.file .. "\";\n";
		if zone.masters then
			config_options = config_options .. "\tmasters {\n";
			for _,master in pairs(zone.masters) do
				config_options = config_options .. "\t\t" .. master .. ";\n";
			end
			config_options = config_options .. "\t};\n";
		end
		config_options = config_options .. "};\n";
	end end
	write_file('/etc/bind/named.conf', config_options)
	return 0
end

filesystem['/var/cache/bind'] = { type="tmpfs", size="128M" }
filesystem['/etc/bind/zones'] = { type="map", path="zones" }
