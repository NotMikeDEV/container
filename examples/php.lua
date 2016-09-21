#!/usr/sbin/container
require("caddy")

function install_cgi()
	install_package("php5-fpm")
end

function run_cgi()
	exec("/usr/sbin/php5-fpm")
end

request_IP("66.85.79.6", {proxyarp='eth0'})

request_IP("2001:470:3922::1:42")

filesystem['/var/log/'] = { type="map", path="log" }
filesystem['/var/lib/php5/sessions'] = { type="tmpfs", size="512M" }
filesystem['/var/www/'] = { type="map", path="docroot" }
filesystem['/root/'] = { type="map", path="home" }
config_files['/etc/Caddyfile'] = [[
:80 {
	fastcgi / /var/run/php5-fpm.sock php
}

https://c.notmike.uk {
	fastcgi / /var/run/php5-fpm.sock php
}
]]

config_files['/var/www/index.php'] = [[
<?php phpinfo(); ?>
]]
