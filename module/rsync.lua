---Rsync Service.
--@module rsync
rsync={
	servers={},
	clients={},
}

---RSync Server
--@field port integer TCP Port server is configured to listen on.
--@table rsyncserver

---RSync Server Directory.
--@field path string Name of directory. Do not include / in the name.
--@field localpath string Local Path to map to.
--@table rsyncdir

---RSync User.
--@field username string
--@field password string
--@table rsyncuser

---Add a new RSync Server.
--@param port integer
--@return rsyncserver
--@usage local rsyncserver = rsync:AddServer(9999)
function rsync:AddServer(port)
--	if rsync.servers[port] then return rsync.servers[port] end
	local rsyncserver = {port=port, dirs={}}
	---Add Directory to RSync server.
	--@param rsyncdir
	--@returns rsyncdir
	--@usage local rsyncserver = rsync:AddServer(9999)
	--rsyncserver:AddDir{path='/test', localpath='/tmp/test'}
	function rsyncserver:AddDir(rsyncdir)
		if not rsyncdir.users then rsyncdir.users = {} end
		---Add User to RSync directory.
		--@param rsyncuser
		--@returns rsyncuser
		--@usage local rsyncserver = rsync:AddServer(9999)
		-- local ServerDir = rsyncserver:AddDir{path='/test', localpath='/tmp/test'}
		-- local ServerDir:AddUser{username='test', password='test'}
		function rsyncdir:AddUser(rsyncuser)
			self.users[rsyncuser.username] = rsyncuser
		end
		self.dirs[rsyncdir.path] = rsyncdir
		return rsyncdir
	end
	rsync.servers[port] = rsyncserver
	return rsyncserver
end

function install_container()
	print("Installing Rsync.")
	install_package("rsync")
	return 0
end

function apply_config()
	mkdir("/etc/rsync")
	for _,server in pairs(rsync.servers) do
		debug_print('apply_config', "RSync Server " .. server.port)
		local config = ""
		config = config .. "pid file=/run/rsync." .. server.port .. ".pid\n"
		config = config .. "lock file=/run/rsync." .. server.port .. ".lock\n"
		config = config .. "log file=/tmp/rsync." .. server.port .. ".log\n"
		config = config .. "port=" .. server.port .. "\n\n"
		for _, dir in pairs(server.dirs) do
			config = config .. "[" .. dir.path .. "]\n"
			config = config .. "path=" .. dir.localpath .. "\n"
			if dir.comment then config = config .. "comment=" .. dir.comment .. "\n" end
			if dir.readonly then config = config .. "readonly=true\n" else config = config .. "readonly=false\n" end
			config = config .. "timeout=60\n"
			local userlist = ""
			local passwordlist = ""
			for _, user in pairs(dir.users) do
				if (userlist:len() > 0) then userlist = userlist .. "," end
				userlist = userlist .. user.username
				passwordlist = passwordlist .. user.username .. ":" .. user.password .. "\n"
			end
			if (userlist:len() > 0) then
				config = config .. "auth users=" .. userlist .. "\n"
				config = config .. "secrets file=/etc/rsync/server." .. server.port .. ".pwd\n"
				write_file('/etc/rsync/server.' .. server.port .. '.pwd', passwordlist)
				exec('chmod 0600 /etc/rsync/server.' .. server.port .. '.pwd')
			end
		end
		write_file('/etc/rsync/server.' .. server.port .. '.conf', config)
	end
	return 0
end

function background()
	for _,server in pairs(rsync.servers) do
		for _, dir in pairs(server.dirs) do
			exec("mkdir -p " .. dir.localpath .. " && chmod 0777 " .. dir.localpath)
		end
		exec('rsync --daemon --config /etc/rsync/server.' .. server.port .. '.conf  &')
	end
	return 0
end
