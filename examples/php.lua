#!/usr/sbin/container
function install_php_site()
end

pre_php_install_cgi = install_cgi
function install_cgi()
	install_package("php5-fpm php5-gd php5-curl php5-sqlite php5-mysql php5-odbc php5-imap php5-mhash php5-memcached php5-ssh2 php5-xcache")
	install_php_site()
	return pre_php_install_cgi()
end

pre_php_run_cgi = run_cgi
function run_cgi()
	exec("/usr/sbin/php5-fpm")
	return pre_php_run_cgi()
end

filesystem['/var/log/'] = { type="map", path="log" }
filesystem['/var/run/'] = { type="map", path=".run" }
filesystem['/var/lib/php5/sessions'] = { type="tmpfs", size="512M" }
filesystem['/var/www/'] = { type="map", path="docroot" }
filesystem['/root/'] = { type="map", path="home" }

pre_php_caddy_config=caddy_config
function caddy_config(settings)
	return "\tfastcgi / /var/run/php5-fpm.sock php {\n\t\tenv PATH /bin\n\t}\n" .. pre_php_caddy_config(settings)
end

config_files['/var/www/index.php'] = [[
<?php phpinfo(); ?>
]]
