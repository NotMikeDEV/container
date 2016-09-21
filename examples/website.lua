#!/usr/sbin/container
require("php")

request_IP("66.85.79.6", {proxyarp='eth0'})
request_IP("2001:470:3922::1:42")

config_files['/etc/Caddyfile'] = [[
http://c.notmike.uk {
	fastcgi / /var/run/php5-fpm.sock php
}
https://c.notmike.uk {
	fastcgi / /var/run/php5-fpm.sock php
}
]]

config_files['/var/www/index.php'] = [[
This is a website.
]]
