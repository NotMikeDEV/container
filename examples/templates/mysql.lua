mysql={databases={}}

mysql.password = read_file(base_path .. '/.mysql-root.pwd')
if not salt then
	mysql.password = ''
	for x = 1, 25 do
		mysql.password = mysql.password .. string.char(math.random(97, 122))
	end
	write_file(base_path .. '/.mysql-root.pwd', mysql.password)
end

function mysql:Database(database)
	if type(database) ~= "table" then database = {database=database} end
	if not database.database then database.database = 'default' end
	
	function database:Grant(user)
		if not user.user then user.user = "user" end
		if not user.password then user.password = "changeme" end
		if not self.users then self.users = {} end
		self.users[user] = user
		return user
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
		if not mysql.running then
			local handle = io.popen('mysqld >/dev/null 2>&1 & echo $!')
			mysql.running = handle:read("*number")
			handle:close()
		end
		local count=0
		while count < 30 do
			if exec('mysql -uroot -p"' .. mysql.password .. '" -e "USE mysql;" 1>/dev/null 2>&1') then
				count = 999
			else
				count = count + 1
				exec("sleep 0.5")
			end
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
			if exec('mysql -uroot -p"' .. mysql.password .. '" -e "GRANT ALL PRIVILEGES ON ' .. database.database .. '.* to \'' .. user.user .. '\'@\'localhost\' IDENTIFIED BY \'' .. user.password .. '\';" 3>/dev/null 2>&1') then
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
	exec("mysqld &")
	return 0
end

if not filesystem['/var/lib/mysql/'] then filesystem['/var/lib/mysql/'] = { type="map", path="mysql" } end
if not filesystem['/var/run/'] then filesystem['/var/run/'] = { type="map", path=".run" } end
