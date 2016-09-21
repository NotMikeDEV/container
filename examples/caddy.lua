#!/usr/sbin/container

function install_cgi()
end

function install_container()
	exec("mkdir -p /usr/src/caddy")
	install_package("ca-certificates")
	exec("wget -O /usr/src/caddy/caddy.tar.gz \"https://caddyserver.com/download/build?os=linux&arch=amd64&features=\"")
	exec("cd /usr/src/caddy; tar -zxf caddy.tar.gz")
	exec("cp /usr/src/caddy/caddy /usr/bin")
	install_cgi()
end

function run_cgi()
end

function run()
	run_cgi()
	exec("/usr/bin/caddy -agree -email fake@user.com -conf /etc/Caddyfile -root /var/www")
	return 0
end

filesystem['/var/www/'] = { type="map", path="docroot" }
filesystem['/root/'] = { type="map", path="home" }
config_files['/etc/Caddyfile'] = [[
:80
]]

config_files['/var/www/index.html'] = [[
<h1>Welcome!</h1>
]]
