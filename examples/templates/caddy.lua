caddy={}
caddy.config = {}

function caddy:AddWebsite(website)
	if not caddy.config.websites then caddy.config.websites = {} end
	
	function website:AddRedirect(params)
		if not self.redirects then self.redirects = {} end
		self.redirects[params.source] = params
		return self
	end

	function website:AddRewrite(params)
		if not self.rewrites then self.rewrites = {} end
		self.rewrites[params.source] = params
		return self
	end
	
	caddy.config.websites[website.hostname or ':8080']=website
	return website
end

function caddy:AddFastCGI(config)
	if not caddy.config.fastcgi then caddy.config.fastcgi = {} end
	caddy.config.fastcgi[config.ext] = config
	return config
end

function caddy.generate_config(website)
	local config = ""
	if website.redirects then
		for source, redirect in pairsByKeys(website.redirects) do
			if not redirect.status then redirect.status = 302 end
			config = config .. "\tredir " .. source .. " " .. redirect.target .. " " .. redirect.status .. "\n"
		end
	end
	if website.rewrites then
		for source, rewrite in pairsByKeys(website.rewrites) do
			config = config .. "\trewrite {\n\t\tregexp\t" .. source .. "\n\t\tto\t" .. rewrite.target .. "\n\t}\n"
		end
	end
	if caddy.config.fastcgi then
		for name, value in pairsByKeys(caddy.config.fastcgi) do
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
	exec("wget -O /usr/src/caddy/caddy.tar.gz \"https://caddyserver.com/download/build?os=linux&arch=amd64&features=\"")
	exec("cd /usr/src/caddy; tar -zxf caddy.tar.gz")
	exec("cp /usr/src/caddy/caddy /usr/bin")
	return 0
end

function apply_config()
	if not caddy.config.websites then return 0 end
	local config = ""
	for host, settings in pairsByKeys(caddy.config.websites) do
		config = config .. host .. " {\n"
		if not settings.root then settings.root = "/var/www" end
		config = config .. "\troot " .. settings.root .. "\n"
		config = config .. caddy.generate_config(settings)
		config = config .. "\n}\n\n"
	end
	write_file("/etc/Caddyfile", config)
	return 0
end

function run()
	if not caddy.config.websites then return 0 end
	print("Starting Caddy.")
	exec("HOME=/root /usr/bin/caddy -agree -email fake@user.com -conf /etc/Caddyfile &")
	return 0
end

filesystem['/var/www/'] = { type="map", path="docroot" }
filesystem['/root/'] = { type="map", path="home" }

if not webserver then webserver = caddy end