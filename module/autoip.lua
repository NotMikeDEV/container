---Container networking auto IP allocation module.
--Will search ./ip.conf then /etc/container/ip.conf. If neither exists it will create /tmp/ip.conf.
--@module autoip
if not network then require("module/network") end

function explode_v4(str)
	local pos,arr = 0,{}
	for st,sp in function() return string.find(str,'.',pos,true) end do
		table.insert(arr,string.sub(str,pos,st-1)) -- Attach chars left of current divider
		pos = sp + 1 -- Jump past current divider
	end
	table.insert(arr,string.sub(str,pos)) -- Attach chars right of last divider
	return arr
end

function explode_v6(str)
	local pos,arr = 0,{}
	for st,sp in function() return string.find(str,':',pos,true) end do
		table.insert(arr,string.sub(str,pos,st-1)) -- Attach chars left of current divider
	pos = sp + 1 -- Jump past current divider
	end
	table.insert(arr,string.sub(str,pos)) -- Attach chars right of last divider
	return arr
end

function implode_v4(parts)
	return table.concat(parts,".")
end
function implode_v6(parts)
	return table.concat(parts,":")
end

local ip_filename = "/tmp/autoip.conf"
if isFile("/etc/container/ip.conf") then ip_filename = "/etc/container/ip.conf" end
if isFile("./ip.conf") then ip_filename = "./ip.conf" end

file = io.open(ip_filename, "r")
if not file then
	write_file(ip_filename, [[
#As many lines containing # as you want.
#A Blank line.
#First line IPv6 prefix (/64).
#Second line IPv4 prefix (/16).
#Third line NAT (true/false).
#Then assignments, example: "80:www".
#Assignments should be 0-255 for dual stack compatibility.

]] .. 'fcfc:' .. math.random(1000,9999) .. ':' .. math.random(1000,9999) .. ':' .. math.random(1000,9999) .. ":0:0:0:0\n" ..
"100." .. math.random(64,127) .. ".0.0\n" ..
"true\n")
	file = io.open(ip_filename, "r")
	if not file then
		die("Check permissions for " .. ip_filename)
	end
end

autoip = {
	prefixes={},
	assignments={},
	assignments_ip={},
	nat=false
}
local line="#"
while line:find('#') do
	line = file:read('*l')
end

autoip.prefixes.ipv6=implode_v4(explode_v4(file:read('*l')))
debug_print('autoip_ipv6', autoip.prefixes.ipv6 .. "/64")
autoip.prefixes.ipv4=implode_v6(explode_v6(file:read('*l')))
debug_print('autoip_ipv4', autoip.prefixes.ipv4 .. "/16")
if (file:read('*l')) then autoip.nat = true else autoip.nat = false end
debug_print('autoip_NAT', autoip.nat)

while true do
	local line = file:read('*l')
	if not line then break end
	
	local parts = explode_v4(line)
	if (#parts > 1) then
		autoip.assignments[parts[2]] = parts[1]
		debug_print("autoip_Assignment", parts[2], parts[1])
	end
end
io.close(file)

---Get the ID of the assignment.
--@param name String Name of container.
--@param preferred[opt] int Preferred IP Address.
--@return int Octet of container IP.
function autoip:GetAssignment(name, preferred)
	if preferred == nil then preferred = 255 end
	if not autoip.assignments[name] then
		local taken = {}
		for name, ip in pairs(autoip.assignments) do
			taken[ip+0] = true
			debug_print("autoip_Taken", ip)
		end
		local ip = preferred
		while taken[ip] do debug_print("autoip_Collide", name, ip) ip = math.floor((ip - 1)%256) end
		debug_print("autoip_Assign", name, ip)
		autoip.assignments[name]=ip
		write_file(ip_filename, read_file(ip_filename) .. ip .. "." .. name .. "\n")
	end
	return autoip.assignments[name]
end

---Get the containers IPv4 assignment.
--@param name String Name of container.
--@param preferred[opt] int Preferred IP Address.
--@return String IPv4 address.
function autoip:GetIPv4(name, preferred)
	local address = explode_v4(autoip.prefixes.ipv4)
	address[4] = autoip:GetAssignment(name, preferred)
	return implode_v4(address)
end

---Get the containers IPv4 /24 prefix assignment.
--@param name String Name of container.
--@param preferred[opt] int Preferred IP Address.
--@return String IPv4 network address. Use mask /24.
function autoip:GetIPv4Prefix(name, preferred)
	local address = explode_v4(autoip.prefixes.ipv4)
	address[3] = autoip:GetAssignment(name, preferred)
	address[4] = '0'
	return implode_v4(address)
end

---Get the containers IPv6 assignment.
--@param name String Name of container.
--@param preferred[opt] int Preferred IP Address.
--@return String IPv6 address.
function autoip:GetIPv6(name, preferred)
	local address = explode_v6(autoip.prefixes.ipv6)
	address[5] = 0
	address[6] = 0
	address[7] = 0
	address[8] = autoip:GetAssignment(name, preferred)
	return implode_v6(address)
end

---Get the containers IPv6 /96 prefix assignment.
--@param name String Name of container.
--@param preferred[opt] int Preferred IP Address.
--@return String IPv6 network address. Use mask /96.
function autoip:GetIPv6Prefix(name, preferred)
	local address = explode_v6(autoip.prefixes.ipv6)
	address[5] = 'A'
	address[6] = autoip:GetAssignment(name, preferred)
	address[7] = 0
	address[8] = 0
	return implode_v6(address)
end

---Automatically assign IPv4 and IPv6 addresses and route Prefixes.
--Do not use this function if you plan to manually assign IP addresses to interfaces.
--@param name String Name of container.
--@param preferred[opt] int Preferred IP Address.
function autoip:AssignIP(name, preferred)
	local Addresses={
		ipv4=autoip:GetIPv4(name, preferred),
		ipv6=autoip:GetIPv6(name, preferred),
		ipv4_24=autoip:GetIPv4Prefix(name, preferred),
		ipv6_96=autoip:GetIPv6Prefix(name, preferred)
	}
	network:AddIP{
		ipv4=Addresses.ipv4,
		ipv6=Addresses.ipv6,
		nat=autoip.nat
	}
	network:AddPrefix{
		ipv4=Addresses.ipv4_24 .. "/24",
		ipv6=Addresses.ipv6_96 .. "/96"
	}
	return Addresses
end
