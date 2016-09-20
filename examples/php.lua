#!/usr/sbin/container

function install_container()
	exec("mkdir -p /usr/src/caddy")
	install_package("ca-certificates")
	exec("wget -O /usr/src/caddy/caddy.tar.gz \"https://caddyserver.com/download/build?os=linux&arch=amd64&features=\"")
	exec("cd /usr/src/caddy; tar -zxf caddy.tar.gz")
	exec("cp /usr/src/caddy/caddy /usr/bin")
	install_package("php5-fpm")
end

function run()
	exec("/usr/sbin/php5-fpm")
	exec("/usr/bin/caddy -agree -email fake@user.com -conf /etc/Caddyfile -root /var/www")
	return 0
end

request_IP("10.0.0.43", {nat=true})
--request_IP("66.85.79.6", {proxyarp='eth0'})

request_IP("fd00::43", {nat=true})
--request_IP("2001:470:3922::1:42")

filesystem['/var/log/'] = { type="map", path="log" }
filesystem['/var/lib/php5/sessions'] = { type="tmpfs", size="512M" }
filesystem['/var/www/'] = { type="map", path="docroot" }
filesystem['/root/'] = { type="map", path="home" }
config_files['/etc/Caddyfile'] = [[
:80 {
	fastcgi / /var/run/php5-fpm.sock php
}

https://caddy.notmike.uk {
	fastcgi / /var/run/php5-fpm.sock php
}
]]

config_files['/var/www/index.php'] = [[
<?php phpinfo(); ?>
]]
