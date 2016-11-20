---OpenSSH Server
--@module sshd
sshd = {}

---Set the root password.
--@param password string
function sshd:SetRootPassword(password)
	sshd.root_password=password
end

function install_container()
	install_package("openssh-server")
	return 0
end

function run()
	exec("/usr/sbin/sshd </dev/null >/dev/null 2>&1 &")
	return 0
end

function apply_config()
	exec("chmod 0700 /run/sshd; chown root:root /run/sshd")
	if not sshd.root_password then
		sshd.root_password =''

		for x = 1, math.random(48,64) do
			if (math.random(0,1) == 1) then
				sshd.root_password = sshd.root_password .. string.char(math.random(97, 122))
			elseif (math.random(0,1) == 1) then
				sshd.root_password = sshd.root_password .. string.char(math.random(65, 90))
			else
				sshd.root_password = sshd.root_password .. string.char(math.random(48, 57))
			end
		end
		print("SSH root password for this session: " .. sshd.root_password)
	end
	exec("( echo \"" .. sshd.root_password .. "\"; echo \"" .. sshd.root_password .. "\" ) | passwd")
	write_file("/etc/ssh/sshd_config", [[
	Port 22
	Protocol 2
	HostKey /etc/ssh/ssh_host_rsa_key
	HostKey /etc/ssh/ssh_host_dsa_key
	HostKey /etc/ssh/ssh_host_ecdsa_key
	HostKey /etc/ssh/ssh_host_ed25519_key
	UsePrivilegeSeparation yes
	KeyRegenerationInterval 3600
	ServerKeyBits 1024
	RSAAuthentication yes
	PubkeyAuthentication yes
	HostbasedAuthentication no
	PasswordAuthentication yes
	TCPKeepAlive yes
	Subsystem sftp /usr/lib/openssh/sftp-server
	UsePAM yes
	PermitRootLogin yes
	]])
	return 0
end
Mount{path="/run/sshd", type='tmpfs'}
Mount{path="/etc/ssh/keys", type='map', source='ssh_keys'}
