#!/usr/sbin/container
require("php")

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
