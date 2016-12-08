---Nignx web server.
--Loading the nginx module automatically exports /var/www to the docroot directory.
--The nginx object is also exposed under the name webserver.
--@module nginx
nginx={
	config = {}
}

---Website configuration.
--@field hostname string Hostname of website.
--@field[opt] port integer Port to listen on.
--@field[opt] root string Path to document root.
--@table website

---Add a new website to nginx server config.
--@see website
--@param website
--@return website
--@usage local WebSite = nginx:AddWebsite{hostname='hostname', root='/path/to/docroot'}
function nginx:AddWebsite(website)
	if not nginx.config.websites then nginx.config.websites = {} end

	if not website.hostname then website.hostname = '' end
	if not website.port then website.port = 80 end
	if not website.root then website.root = "/var/www" end
	if website.hostname:find(":") then
		website.port = website.hostname:sub(website.hostname:find(":")+1)
		website.hostname = website.hostname:sub(0, website.hostname:find(":")-1)
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
	--@usage local WebSite = nginx:AddWebsite{hostname='hostname', root='/path/to/docroot'}
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
	--@usage local WebSite = nginx:AddWebsite{hostname='hostname', root='/path/to/docroot'}
	--WebSite:AddRewrite{source='/source', target='/target'}
	function website:AddRewrite(rewrite)
		if not self.rewrites then self.rewrites = {} end
		self.rewrites[rewrite.source] = rewrite
		return self
	end
	
	---Proxy rule.
	--@field source string Source Path.
	--@field target string Target to proxy to.
	--@field[opt] hostname string Rewirte Host: header.
	--@table proxy

	---Add proxy rule to the website.
	--@see proxy
	--@see website
	--@param proxy
	--@return website
	--@usage local WebSite = nginx:AddWebsite{hostname='hostname', root='/path/to/docroot'}
	--WebSite:AddProxy{source='/', target='127.0.0.1:8080'}
	function website:AddProxy(proxy)
		if not self.proxies then self.proxies = {} end
		self.proxies[proxy.source] = proxy
		return self
	end
	
	nginx.config.websites[website.hostname .. ':' .. website.port]=website
	return website
end

function nginx:AddFastCGI(config)
	if not nginx.config.fastcgi then nginx.config.fastcgi = {} end
	nginx.config.fastcgi[config.ext] = config
	return config
end

function nginx.generate_config(website)
	local config = ""
	config = config .. "server{\n"
	config = config .. "\troot " .. website.root .. ";\n"
	if website.hostname:len() > 0 then config = config .. "\tserver_name " .. website.hostname .. ";\n" end
	config = config .. "\tlisten [::]:" .. website.port .. ";\n"
	config = config .. "\tlisten " .. website.port .. ";\n"
	if website.redirects then
		for source, redirect in pairsByKeys(website.redirects) do
			config = config .. "\trewrite " .. source .. " " .. redirect.target .. " redirect;\n"
		end
	end
	if website.rewrites then
		for source, rewrite in pairsByKeys(website.rewrites) do
			config = config .. "\trewrite " .. source .. " " .. rewrite.target .. ";\n"
		end
	end
	if website.proxies then
		for source, data in pairsByKeys(website.proxies) do
			config = config .. "\tlocation " .. source .. " {\n"
			config = config .. "\t\tproxy_pass " .. data.target .. ";\n"
			config = config .. "\t\tproxy_redirect " .. data.target .. " " .. source .. ";\n"
			if data.hostname then config = config .. "\t\tproxy_set_header Host " .. data.hostname .. ";\n" end
			config = config .. "\t\tproxy_set_header X-Real-IP $remote_addr;\n"
			config = config .. "\t\tproxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;\n"
			config = config .. "\t}\n"
		end
	end
	if nginx.config.fastcgi then
		for name, value in pairsByKeys(nginx.config.fastcgi) do
			config = config .. "\tlocation ~ \\.(" .. value.ext .. ")$ {\n"
			config = config .. "\t\tfastcgi_pass " .. value.socket .. ";\n"
			config = config .. "\t\tfastcgi_param SCRIPT_FILENAME $document_root$fastcgi_script_name;\n"
			config = config .. "\t\tfastcgi_param QUERY_STRING    $query_string;\n"
			config = config .. "\t}\n"
		end
	end
	config = config .. "}\n"
	return config
end

function install_container()
	print("Installing Nginx.")
	install_package("nginx-full")
	exec("rm -f ./etc/nginx/sites-enabled/default")
	return 0
end

function apply_config()
	if not nginx.config.websites then return 0 end
	local config = ""
	for _, website in pairsByKeys(nginx.config.websites) do
		config = config .. nginx.generate_config(website)
	end
	write_file("/etc/nginx/sites-enabled/container", config)
	return 0
end

function run()
	if not nginx.config.websites then return 0 end
	print("Starting Nginx.")
	exec_or_die("/usr/sbin/nginx")
	return 0
end

Mount{path='/var/www/', type="map", source="docroot" }
Mount{path='/var/log/nginx/', type="tmpfs"}
Mount{path='/var/lib/nginx/', type="tmpfs"}

if not webserver then webserver = nginx end