---Caddy web server.
--Loading the caddy module automatically exports /var/www to the docroot directory and /root to the home directory.
--The caddy object is also exposed under the name webserver.
--@module caddy
caddy={}
caddy.config = {}

---Website configuration.
--@field hostname string Hostname of website.
--@field[opt] port integer Port to listen on.
--@field[opt] root string Path to document root.
--@table website

---Add a new website to caddy server config.
--@see website
--@param website
--@return website
--@usage local WebSite = caddy:AddWebsite{hostname='hostname', root='/path/to/docroot'}
function caddy:AddWebsite(website)
	if not caddy.config.websites then caddy.config.websites = {} end

	if not website.hostname then website.hostname = '' end
	if not website.port then website.port = 80 end
	if not website.root then website.root = "/var/www" end
	if website.hostname:find(":") then
		website.port = website.hostname:sub(website.hostname:find(":")+1)
		website.hostname = website.hostname:sub(0, website.hostname:find(":") -1)
	end

	---Redirect configuration.
	--@field source string Source Path.
	--@field target string Target Path.
	--@field[opt] status int Status code to return.
	--@table redirect
	
	---Add redirect rule to the website.
	--@see redirect
	--@see website
	--@param redirect
	--@return website
	--@usage local WebSite = caddy:AddWebsite{hostname='hostname', root='/path/to/docroot'}
	--WebSite:AddRedirect{source='/source', target='/target', status=status}
	function website:AddRedirect(redirect)
		if not self.redirects then self.redirects = {} end
		self.redirects[redirect.source] = redirect
		return self
	end

	---Rewrite rule.
	--@field source string Source Path.
	--@field target string Target Path.
	--@table rewrite

	---Add rewrite rule to the website.
	--@see rewrite
	--@see website
	--@param rewrite
	--@return website
	--@usage local WebSite = caddy:AddWebsite{hostname='hostname', root='/path/to/docroot'}
	--WebSite:AddRewrite{source='/source', target='/target'}
	function website:AddRewrite(rewrite)
		if not self.rewrites then self.rewrites = {} end
		self.rewrites[rewrite.source] = rewrite
		return self
	end
	
	---Proxy rule.
	--@field source string Source Path.
	--@field target string Target to proxy to.
	--@field hostname[opt] string Host: header to send to server.
	--@table proxy

	---Add proxy rule to the website.
	--@see proxy
	--@see website
	--@param proxy
	--@return website
	--@usage local WebSite = caddy:AddWebsite{hostname='hostname', root='/path/to/docroot'}
	--WebSite:AddProxy{source='/', target='127.0.0.1:8080'}
	function website:AddProxy(proxy)
		if not self.proxies then self.proxies = {} end
		self.proxies[proxy.source] = proxy
		return self
	end

	---Websocket application.
	--@field source string Source Path.
	--@field target string Target application.
	--@table websocket

	---Add websocket rule to the website.
	--@see websocket
	--@see website
	--@param websocket
	--@return website
	--@usage local WebSite = caddy:AddWebsite{hostname='hostname', root='/path/to/docroot'}
	--WebSite:AddWebsocket{source='/cat', target='/bin/cat'}
	function website:AddWebsocket(websocket)
		if not self.websockets then self.websockets = {} end
		self.websockets[websocket.source] = websocket
		return self
	end
	
	caddy.config.websites[website.hostname .. ':' .. website.port]=website
	return website
end

---FastCGI server.
--@field ext string Filename extension to match.
--@field socket string Socket to connect to.
--@table fastcgiserver

---Add a new FastCGI server caddy server config.
--@see fastcgiserver
--@param fastcgiserver
--@return fastcgiserver
function caddy:AddFastCGI(fastcgiserver)
	if not caddy.config.fastcgi then caddy.config.fastcgi = {} end
	caddy.config.fastcgi[fastcgiserver.ext] = fastcgiserver
	return fastcgiserver
end

function caddy.generate_config(website)
	local config = ""
	if website.redirects then
		for source, redirect in pairsByKeys(website.redirects) do
			debug_print('caddy.generate_config', "Redirect " .. source)
			if not redirect.status then redirect.status = 302 end
			config = config .. "\tredir " .. source .. " " .. redirect.target .. " " .. redirect.status .. "\n"
		end
	end
	if website.rewrites then
		for source, rewrite in pairsByKeys(website.rewrites) do
			debug_print('caddy.generate_config', "Rewrite " .. source)
			config = config .. "\trewrite {\n\t\tregexp\t" .. source .. "\n\t\tto\t" .. rewrite.target .. "\n\t}\n"
		end
	end
	if website.proxies then
		for source, data in pairsByKeys(website.proxies) do
			debug_print('caddy.generate_config', "Proxy " .. source)
			config = config .. "\tproxy " .. source .. " " .. data.target .. " {\n"
			if data.hostname then
				config = config .. "\t\theader_upstream Host " .. data.hostname .. "\n"
			else
				config = config .. "\t\theader_upstream Host {host}\n"
			end
			config = config .. "\t\theader_upstream X-Real-IP {remote}\n"
			config = config .. "\t\theader_upstream X-Forwarded-For {remote}\n"
			config = config .. "\t\theader_upstream X-Forwarded-Proto {scheme}\n"
			config = config .. "\t}\n"

		end
	end
	if website.websockets then
		for source, rewrite in pairsByKeys(website.websockets) do
			debug_print('caddy.generate_config', "Websocket " .. source)
			config = config .. "\twebsocket " .. source .. " " .. rewrite.target .. "\n"
		end
	end
	if caddy.config.fastcgi then
		for name, value in pairsByKeys(caddy.config.fastcgi) do
			debug_print('caddy.generate_config', "FastCGI " .. name)
			config = config .. "\tfastcgi / " .. value.socket .. " {\n"
			config = config .. "\t\text\t." .. name .. "\n"
			config = config .. "\t\tsplit\t." .. name .. "\n"
			config = config .. "\t\tindex\tindex." .. name .. "\n"
			config = config .. "\t}\n"
		end
	end
	return config
end

function install_container()
	print("Installing Caddy.")
	exec("mkdir -p /usr/src/caddy")
	install_package("ca-certificates")
	debug_print('install_container', "Detecting architecture:")
	local caddyarch = debian.arch
	if caddyarch:find("amd64") then caddyarch = "amd64"
	elseif caddyarch:find("x86_64") then caddyarch = "amd64"
	elseif caddyarch:find("86") then caddyarch = "386"
	elseif caddyarch:find("arm") then caddyarch = "arm"
	end
	debug_print('install_container', caddyarch)

	exec_or_die("wget -O /usr/src/caddy/caddy.tar.gz http://cache.linuxship.net/caddy/caddy-" .. caddyarch .. ".tar.gz" ..
		"|| wget -O /usr/src/caddy/caddy.tar.gz \"https://caddyserver.com/download/linux/" .. caddyarch .. "\"")
	exec_or_die("cd /usr/src/caddy; tar -zxf caddy.tar.gz")
	exec_or_die("cp /usr/src/caddy/caddy /usr/bin")
	return 0
end

function apply_config()
	if not caddy.config.websites then return 0 end
	local config = ""
	debug_print('apply_config', "Generating Caddy config.")
	for _, website in pairsByKeys(caddy.config.websites) do
		debug_print('apply_config', website.hostname .. ':' .. website.port)
		config = config .. website.hostname .. ':' .. website.port .. " {\n"
		if not website.root then website.root = "/var/www" end
		config = config .. "\troot " .. website.root .. "\n"
		config = config .. caddy.generate_config(website)
		config = config .. "\n}\n\n"
	end
	write_file("/etc/Caddyfile", config)
	return 0
end

function background()
	if not caddy.config.websites then return 0 end
	print("Starting Caddy.")
	exec("HOME=/root /usr/bin/caddy -agree -email fake@user.com -conf /etc/Caddyfile")
	return 0
end

Mount{ path='/var/www/', type="map", source="docroot" }
Mount{ path='/root/', type="map", source="home" }

if not webserver then webserver = caddy end
