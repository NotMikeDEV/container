#!/usr/sbin/container

mysql_password="notdefined"

pre_mysql_install_container = install_container
function install_container()
	exec('echo "mysql-server mysql-server/root_password password ' .. mysql_password .. '" | debconf-set-selections')
	exec('echo "mysql-server mysql-server/root_password_again password ' .. mysql_password .. '" | debconf-set-selections')
	install_package("mysql-server")
	return pre_mysql_install_container()
end

filesystem['/var/lib/mysql/'] = { type="map", path="mysql" }
filesystem['/var/run/mysqld/'] = { type="map", path=".run" }

post_mysql_run=run
function run()
	exec("mysqld &")
	return post_mysql_run()
end
