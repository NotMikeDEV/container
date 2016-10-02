#!/usr/sbin/container
require("caddy")
require("php")
require("mysql")

request_IP("2001:470:3922::ccc")
websites["owncloud.offsite.notmike.uk"]={}
websites["owncloud.offsite.notmike.uk"].root='/var/www/owncloud'

mysql_password="owncloud1234567"

function install_php_site()
	file = io.open("etc/apt/sources.list.d/owncloud.list", "w")
	if not file then return 1 end
	io.output(file)
	io.write("deb http://download.owncloud.org/download/repositories/9.0/Debian_8.0/ /")
	io.close(file)
	exec("wget -nv https://download.owncloud.org/download/repositories/9.0/Debian_8.0/Release.key -O /dev/stdout -o /dev/null | apt-key add - ")
	exec("apt-get update")
	install_package("owncloud-files")
	exec('mkdir /var/run/mysqld/ ; chmod 0777 /var/run/mysqld/; mysqld & sleep 5')
	exec('mysql -uroot -p"' .. mysql_password .. '" -e "CREATE DATABASE owncloud;"')
end

pre_owncloud_caddy_config=caddy_config
function caddy_config(settings)
        return pre_owncloud_caddy_config(settings) .. [[

	rewrite {
		r ^/index.php/.*$
		to /index.php?{query}
	}

	# client support (e.g. os x calendar / contacts)
	redir /.well-known/carddav /remote.php/carddav 301
	redir /.well-known/caldav /remote.php/caldav 301

	# remove trailing / as it causes errors with php-fpm
	rewrite {
		r ^/remote.php/(webdav|caldav|carddav|dav)(\/?)$
		to /remote.php/{1}
	}
	rewrite {
		r ^/remote.php/(webdav|caldav|carddav|dav)/(.+?)(\/?)$
		to /remote.php/{1}/{2}
	}

	# .htacces / data / config / ... shouldn't be accessible from outside
	rewrite {
		r  ^/(?:\.htaccess|data|config|db_structure\.xml|README)
		to /404
	}
	]]
end
