---Samba File Server.
--	require("module/samba")
--	
--	samba.hostname = 'FILESERVER'
--	samba:Share{name='test', path='/mnt/test', browseable=true}
--@module samba

---Samba Configuration.
samba = {
	workgroup = "WORKGROUP",--Workgroup.
	hostname = "SAMBA"--Server Name.
}

---Samba File Share.
--@field name string Name of share.
--@field path string Path to share.
--@field[opt] description string Description of share.
--@field[opt] browseable boolean List share in browse requests.
--@field[opt] readonly boolean Set share as read-only.
--@table share

---Add a new share.
--@param share
--@return share
--@see share
--@usage local FileStore = samba:Share{name='test', path='/mnt/test', browseable=true}
function samba:Share(share)
	if not samba.shares then samba.shares = {} end
	if not share.name then share.name = "unnamed" end
	if not share.path then share.path = "../" .. share.name end
	Mount{path='/samba/' .. share.name, type="map", source=share.path }
	share.path = '/samba/' .. share.name
	if not share.description then share.description = share.name end
	if not share.mask then share.mask = "0755" end
	samba.shares[share.name] = share
	return share
end

function install_container()
	install_package("samba")
	return 0
end

function run()
	print("Starting Samba.")
	exec("smbd &")
	return 0
end

function apply_config()
	local config = ""
	config = config .. "[global]\n"
	config = config .. "netbios name = " .. samba.hostname .. "\n"
	config = config .. "workgroup = " .. samba.workgroup .. "\n"
	config = config .. "dns proxy = no\n"
	config = config .. "vfs objects = acl_xattr\n"
	config = config .. "map acl inherit = yes\n"
	config = config .. "store dos attributes = yes\n"
	config = config .. "log file = /var/log/samba/%m.log\n"
	config = config .. "passdb backend = tdbsam\n"
	config = config .. "syslog only = no\n"
	
	config = config .. "server role = standalone server\n"
	config = config .. "guest account = nobody\n"
	config = config .. "map to guest = bad user\n"

	if samba.shares then for _, share in pairs(samba.shares) do
		config = config .. "[" .. share.name .. "]\n"
		config = config .. "path = " .. share.path .. "\n"
		config = config .. "comment = " .. share.description .. "\n"
		config = config .. "create mask = " .. share.mask .. "\n"
		config = config .. "directory mask = " .. share.mask .. "\n"
		config = config .. "guest ok = yes\n"
		config = config .. "writeable = yes\n"

		if share.browseable then config = config .. "browseable = yes\n" else config = config .. "browseable = no\n" end
		if share.readonly then config = config .. "read only = yes\n" end
	end end
	write_file('/etc/samba/smb.conf', config)
	return 0
end

Mount{path='/var/lib/samba/', type="map", source=".lib" }
Mount{path='/var/cache/samba', type="map", source=".cache" }
Mount{path='/var/log/samba', type="map", source=".log" }
Mount{path='/samba/', type="tmpfs" }
