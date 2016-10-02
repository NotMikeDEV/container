#!/usr/sbin/container

function install_cgi()
end

pre_caddy_install_container = install_container
function install_container()
	exec("mkdir -p /usr/src/caddy")
	install_package("ca-certificates")
	exec("wget -O /usr/src/caddy/caddy.tar.gz \"https://caddyserver.com/download/build?os=linux&arch=amd64&features=\"")
	exec("cd /usr/src/caddy; tar -zxf caddy.tar.gz")
	exec("cp /usr/src/caddy/caddy /usr/bin")
	install_cgi()
	return pre_caddy_install_container()
end

function run_cgi()
end

websites={}
websites[':8080']={}

function caddy_config(settings)
	return ""
end

pre_caddy_apply_config=apply_config
function apply_config()
	file = io.open("/etc/Caddyfile", "w")
	if not file then return 1 end
	io.output(file)
	for host, settings in pairsByKeys(websites) do
		io.write(host .. " {\n")
		if not settings.root then settings.root = "/var/www" end
		io.write("\troot " .. settings.root .. "\n")
		io.write(caddy_config(settings))
		io.write("\n}\n\n")
	end
	io.close(file)
	return pre_caddy_apply_config()
end

pre_caddy_run=run
function run()
	run_cgi()
	exec("HOME=/root /usr/bin/caddy -agree -email fake@user.com -conf /etc/Caddyfile &")
	return pre_caddy_run()
end

filesystem['/var/www/'] = { type="map", path="docroot" }
filesystem['/root/'] = { type="map", path="home" }

config_files['/var/www/index.html'] = [[
<h1>Welcome!</h1>
]]
