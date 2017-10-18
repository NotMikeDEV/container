---Wordpress web application.
--@module wordpress
wordpress={}
wordpress.instances={}

---Create Wordpress instance.
--@param website {hostname='hostname'}
--@return website
function wordpress:Instance(website)
	if not website then website = {} end
	if not website.root then website.root='/wordpress/' .. website.hostname .. '/' end

	if mysql and not website.mysql then website.mysql = mysql:Database{database=website.hostname:gsub('%.','_')} end
	if mysql and website.mysql then website.mysql_auth = website.mysql:Grant{user='wordpress', password=website.hostname} end

	wordpress.instances[website.root] = website
	return website
end

function apply_config()
	for path, instance in pairs(wordpress.instances) do
		if not exists(path .. '/index.php') then
			print("Installing wordpress in " .. path)
			exec("mkdir -p ./" .. path)
			exec("tar --skip-old-files -xf ./var/cache/wordpress.cache -C " .. path)
			exec("chown www-data:www-data -R ./" .. path)
			exec("chmod +r -R ./" .. path)
		end
		if instance.mysql and mysql then
			local salt = read_file('/etc/wordpress/config-' .. instance.hostname .. '.salt')
			if not salt then
				salt = ''
				for x = 1, 30 do
					salt = salt .. string.char(math.random(97, 122))
				end
				write_file('/etc/wordpress/config-' .. instance.hostname .. '.salt', salt)
			end

			local wp_config = "<?php\n/* Auto-generated */\n"
			wp_config = wp_config .. "define('DB_NAME', '" .. instance.mysql.database .. "');\n"
			wp_config = wp_config .. "define('DB_USER', '" .. instance.mysql_auth.user .. "');\n"
			wp_config = wp_config .. "define('DB_PASSWORD', '" .. instance.mysql_auth.password .. "');\n"
			wp_config = wp_config .. "define('DB_HOST', 'localhost');\n"
			wp_config = wp_config .. "define('DB_CHARSET', 'utf8');\n"
			wp_config = wp_config .. "define('DB_COLLATE', '');\n"
			wp_config = wp_config .. "define('UPLOADS', 'uploads');\n"
			wp_config = wp_config .. "define('AUTH_KEY',         '" .. salt .. "auth');\n"
			wp_config = wp_config .. "define('SECURE_AUTH_KEY',  '" .. salt .. "secauth');\n"
			wp_config = wp_config .. "define('LOGGED_IN_KEY',    '" .. salt .. "login');\n"
			wp_config = wp_config .. "define('NONCE_KEY',        '" .. salt .. "nonce');\n"
			wp_config = wp_config .. "define('AUTH_SALT',        '" .. salt .. "authsalt');\n"
			wp_config = wp_config .. "define('SECURE_AUTH_SALT', '" .. salt .. "secauthsalt');\n"
			wp_config = wp_config .. "define('LOGGED_IN_SALT',   '" .. salt .. "loginsalt');\n"
			wp_config = wp_config .. "define('NONCE_SALT',       '" .. salt .. "noncesalt');\n"
			wp_config = wp_config .. "?>\n"
			write_file('/etc/wordpress/config-' .. instance.hostname .. '.php', wp_config)
		end
	end
	return 0
end

function install_container()
	print("Installing wordpress.")
	install_package("wordpress")
	print("Saving cache...")
	exec("cd ./usr/share/wordpress/; tar -cf ../../../var/cache/wordpress.cache .")
	return 0
end

Mount{path='/wordpress/', type="map", source="wordpress" }
