#!/usr/sbin/container

mysql={}
mysql.password="notdefined"

function install_container()
	print("Installing MySQL.")
	exec('echo "mysql-server mysql-server/root_password password ' .. mysql.password .. '" | debconf-set-selections')
	exec('echo "mysql-server mysql-server/root_password_again password ' .. mysql.password .. '" | debconf-set-selections')
	install_package("mysql-server")
	return 0
end

function run()
	print("Starting MySQL.")
	exec("mysqld &")
	return 0
end

if not filesystem['/var/lib/mysql/'] then filesystem['/var/lib/mysql/'] = { type="map", path="mysql" } end
if not filesystem['/var/run/'] then filesystem['/var/run/'] = { type="map", path=".run" } end
