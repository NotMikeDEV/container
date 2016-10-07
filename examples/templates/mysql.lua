mysql={databases={}}
mysql.password="notdefined"

function mysql:Database(database)
	if type(database) ~= "table" then database = {database=database} end
	if not database.database then database.database = 'default' end
	
	function database:Grant(user)
		if not user.user then user.user = "user" end
		if not user.password then user.password = "changeme" end
		if not self.users then self.users = {} end
		self.users[user] = user
		return self
	end

	mysql.databases[database]=database
	return database
end

function install_container()
	print("Installing MySQL.")
	exec('echo "mysql-server mysql-server/root_password password ' .. mysql.password .. '" | debconf-set-selections')
	exec('echo "mysql-server mysql-server/root_password_again password ' .. mysql.password .. '" | debconf-set-selections')
	install_package("mysql-server")
	return 0
end

function apply_config()
	for _, database in pairs(mysql.databases) do
		if mysql and not mysql.running then
			exec('mysqld >/dev/null 2>&1 & sleep 3')
			mysql.running = true
		end
		if not exists('/var/lib/mysql/' .. database.database .. '/db.opt') then
			if exec('mysql -uroot -p"' .. mysql.password .. '" -e "CREATE DATABASE ' .. database.database .. ';" 1>/dev/null 2>&1') then
				print('Created MySQL Database "' .. database.database .. '"')
			else
				print('Failed to create database ' .. database.database)
			end
		else
			print('Loaded database ' .. database.database)
		end
		if database.users then for _, user in pairs(database.users) do
			if exec('mysql -uroot -p"' .. mysql.password .. '" -e "GRANT ALL PRIVILEGES ON ' .. database.database .. '.* to \'' .. user.password .. '\'@\'%\' IDENTIFIED BY \'' .. user.user .. '\';" 1>/dev/null 2>&1') then
				print('Granted ' .. user.user .. ' access to database ' .. database.database)
			end
		end end
	end
	exec("killall -s TERM mysqld")
	exec("killall -s KILL mysqld")
	exec("sleep 1")
	exec("pstree -a")
	return 0
end

function run()
	print("Starting MySQL.")
	exec("mysqld &")
	return 0
end

if not filesystem['/var/lib/mysql/'] then filesystem['/var/lib/mysql/'] = { type="map", path="mysql" } end
if not filesystem['/var/run/'] then filesystem['/var/run/'] = { type="map", path=".run" } end
