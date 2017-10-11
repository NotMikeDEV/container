---MySQL server.
--An auto-generated root password is stored in the mysql directory as .mysql-root.pwd.
--@module mysql
mysql={databases={}}

---Add a database to MySQL server.
--@param database string Datbase name
--@return databse
--@usage local Database = mysql:Database('testdb')
function mysql:Database(database)
	if type(database) ~= "table" then database = {database=database} end
	if not database.database then database.database = 'default' end
	
	---Database User.
	--@field username string Username.
	--@field password string Password.
	--@table dbuser

	---Grant access to database.
	--@param dbuser {user='username',password='password'}
	--@usage local Database = mysql:Database('testdb')
	--@see dbuser
	function database:Grant(dbuser)
		if not dbuser.user then dbuser.user = "user" end
		if not dbuser.password then dbuser.password = "changeme" end
		if not self.users then self.users = {} end
		self.users[dbuser] = dbuser
		return dbuser
	end

	mysql.databases[database]=database
	return database
end

function mysql.passwordfile(file, length)
	local passwd_chars = {'A','B','C','D','E','F','G','H','I','J','K','L','M','N','O','P','Q','R','S','T','U','V','W','X','Y','Z','a','b','c','d','e','f','g','h','i','j','k','l','m','n','o','p','q','r','s','t','u','v','w','x','y','z','0','1','2','3','4','5','6','7','8','9'}
	if not length then length = 32 end
	
	local password = read_file(file)
	if not password then
		password = ''
		for x = 1, length do
			password = password .. passwd_chars[math.random(#passwd_chars)]
		end
		write_file(file, password)
	end
	return password
end

function install_container()
	print("Installing MySQL.")
	exec('echo "mysql-server mysql-server/root_password password ' .. mysql.passwordfile('./var/lib/mysql/.mysql-root.pwd') .. '" | debconf-set-selections')
	exec('echo "mysql-server mysql-server/root_password_again password ' .. mysql.passwordfile('./var/lib/mysql/.mysql-root.pwd') .. '" | debconf-set-selections')
	install_package("mysql-server")
	return 0
end

function apply_config()
	local mysql_password = mysql.passwordfile('./var/lib/mysql/.mysql-root.pwd')
	for _, database in pairs(mysql.databases) do
		if not mysql.running then
			local handle = io.popen('mysqld >/dev/null 2>&1 & echo $!')
			mysql.running = handle:read("*number")
			handle:close()
		end
		local count=0
		while count < 30 do
			if exec('mysql -uroot -p"' .. mysql_password .. '" -e "USE mysql;" 1>/dev/null 2>&1') then
				count = 999
			else
				count = count + 1
				exec("sleep 0.5")
			end
		end
		
		if not exists('/var/lib/mysql/' .. database.database .. '/db.opt') then
			if exec('mysql -uroot -p"' .. mysql_password .. '" -e "CREATE DATABASE ' .. database.database .. ';" 1>/dev/null 2>&1') then
				print('Created MySQL Database "' .. database.database .. '"')
			else
				print('Failed to create database ' .. database.database)
			end
		else
			print('Loaded database ' .. database.database)
		end

		if database.users then for _, user in pairs(database.users) do
			if exec('mysql -uroot -p"' .. mysql_password .. '" -e "GRANT ALL PRIVILEGES ON ' .. database.database .. '.* to \'' .. user.user .. '\'@\'localhost\' IDENTIFIED BY \'' .. user.password .. '\';" 1>/dev/null 2>&1') then
				print('Granted ' .. user.user .. ' access to database ' .. database.database)
			else
				print('Failed to grant ' .. user.user .. ' access to database ' .. database.database)
			end
		end end
	end

	if mysql.running then
		exec("kill -s TERM " .. mysql.running)
		exec("kill -s KILL " .. mysql.running)
		exec("sleep 1")
	end
	mysql.running = false
	return 0
end

function run()
	print("Starting MySQL.")
	exec("mkdir -p /var/run/mysqld && chmod 0777 /var/run/mysqld")
	exec("mysqld &")
	return 0
end

Mount{ path='/var/lib/mysql/', type="map", source="mysql" }
Mount{ path='/var/run/', type="map", source=".run" }
