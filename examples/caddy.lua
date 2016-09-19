#!/usr/sbin/container

function install_container()
	exec("mkdir -p /usr/src/caddy")
	exec("wget -O /usr/src/caddy/caddy.tar.gz --no-check-certificate \"https://caddyserver.com/download/build?os=linux&arch=amd64&features=\"")
	exec("cd /usr/src/caddy; tar -zxf caddy.tar.gz")
	exec("cp /usr/src/caddy/caddy /usr/bin")
end

function run()
	os.execute("/usr/bin/caddy -agree -email fake@user.com -conf /etc/Caddyfile -root /var/www")
	return 0
end

request_IP("10.0.0.42", {nat=true})
--request_IP("66.85.79.6", {proxyarp='eth0'})

request_IP("fd00::3", {nat=true})
--request_IP("2001:470:3922::1:42")

filesystem['/var/www/'] = { type="map", path="docroot" }
filesystem['/root/'] = { type="map", path="home" }
config_files['/etc/Caddyfile'] = [[
http://* http://*.* http://*.*.* http://*.*.*.* http://*.*.*.*.* {
}

https://caddy.notmike.uk {
	tls {
		max_certs 10
	}
}
]]

config_files['/var/www/index.html'] = [[
<h1>Welcome!</h1>
]]