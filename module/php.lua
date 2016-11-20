---PHP FastCGI Module.
--Automatically registers .php extension with caddy.
--@module php
php={}

function install_container()
	print("Installing PHP.")
	install_package("php5-fpm php5-cli php5-gd php5-curl php5-sqlite php5-mysql php5-odbc php5-imap php5-mhash php5-memcached php5-ssh2 php5-xcache")
	return 0
end

function background()
	print("Starting PHP.")
	exec("/usr/sbin/php5-fpm")
	return 0
end

Mount{ path='/var/log/', type="map", source="log" }
Mount{ path='/var/run/', type="map", source=".run" }
Mount{ path='/var/lib/php5/sessions', type="tmpfs", size="512M" }

if webserver then webserver:AddFastCGI{ext='php',socket='/var/run/php5-fpm.sock'} end
