---PHP FastCGI Module.
--Automatically registers .php extension with caddy or nginx as FastCGI module.
--@module php

---PHP Configuration
php={
	short_open_tag		="Off",	--Default off.
	output_buffering	=4096,	--Default buffer size, default 4096.
	output_compression	="Off",	--Compress output buffer. Default off.
	memory_limit		="64M",	--PHP script memory limit. Default 64M.
	post_max_size		="128M",--Max POST Data size. Default 128M.
	upload_max_filesize	="128M",--Max total size of file uploads. Default 128M.
	max_file_uploads	=30,	--Max number of files per POST. Default 30.
	debug			=false,	--Debug Mode. Sets Error Reporting. Enables xdebug remote debugging. Default false.
}
if php.debug then php.error_reporting = "E_ALL" else php.error_reporting = "E_NONE" end

function install_container()
	print("Installing PHP.")
	install_package("php-fpm php-cli php-gd php-curl php-mysql php-sqlite3 php-odbc php-imap php-memcached php-ssh2 php-zip php-xml php-dom php-xdebug")
	return 0
end

function apply_config()
	local PHPINI = "[PHP]\n"
	if php.debug then
		PHPINI = PHPINI .. [[
engine=On
expose_php = On
display_errors = On
display_startup_errors = On
]]
	else
		PHPINI = PHPINI .. [[
engine=On
expose_php=off
display_errors = Off
display_startup_errors = Off
]]	
	end
	PHPINI = PHPINI .. "short_open_tag = " .. php.short_open_tag .."\n"
	PHPINI = PHPINI .. "output_buffering = " .. php.output_buffering .."\n"
	PHPINI = PHPINI .. "zlib.output_compression = " .. php.output_compression .."\n"
	PHPINI = PHPINI .. "memory_limit = " .. php.memory_limit .."\n"
	PHPINI = PHPINI .. "post_max_size = " .. php.post_max_size .."\n"
	PHPINI = PHPINI .. "error_reporting = " .. php.error_reporting .."\n"
	PHPINI = PHPINI .. "upload_max_filesize = " .. php.upload_max_filesize .."\n"
	PHPINI = PHPINI .. "max_file_uploads = " .. php.max_file_uploads .."\n"
	PHPINI = PHPINI .. [[
asp_tags = Off
precision = 14
implicit_flush = Off
unserialize_callback_func =
serialize_precision = 32
disable_functions = pcntl_alarm,pcntl_fork,pcntl_waitpid,pcntl_wait,pcntl_wifexited,pcntl_wifstopped,pcntl_wifsignaled,pcntl_wexitstatus,pcntl_wtermsig,pcntl_wstopsig,pcntl_signal,pcntl_signal_dispatch,pcntl_get_last_error,pcntl_strerror,pcntl_sigprocmask,pcntl_sigwaitinfo,pcntl_sigtimedwait,pcntl_exec,pcntl_getpriority,pcntl_setpriority,
disable_classes =
zend.enable_gc = On
max_execution_time = 30
max_input_time = 60
log_errors = On
log_errors_max_len = 1024
ignore_repeated_errors = Off
ignore_repeated_source = Off
report_memleaks = On
track_errors = Off
html_errors = On
variables_order = "GPCS"
request_order = "GP"
register_argc_argv = Off
auto_globals_jit = On
auto_prepend_file =
auto_append_file =
default_mimetype = "text/html"
default_charset = "UTF-8"
doc_root =
user_dir =
enable_dl = Off
file_uploads = On
allow_url_fopen = On
allow_url_include = Off
default_socket_timeout = 15
[ODBC]
odbc.allow_persistent = On
odbc.check_persistent = On
odbc.max_persistent = -1
odbc.max_links = -1
odbc.defaultlrl = 4096
odbc.defaultbinmode = 1
[Interbase]
ibase.allow_persistent = 1
ibase.max_persistent = -1
ibase.max_links = -1
ibase.timestampformat = "%Y-%m-%d %H:%M:%S"
ibase.dateformat = "%Y-%m-%d"
ibase.timeformat = "%H:%M:%S"
[MySQL]
mysql.allow_local_infile = On
mysql.allow_persistent = On
mysql.max_persistent = -1
mysql.max_links = -1
mysql.connect_timeout = 15
[MySQLi]
mysqli.max_persistent = -1
mysqli.allow_persistent = On
mysqli.max_links = -1
mysqli.default_port = 3306
mysqli.reconnect = Off
[PostgreSQL]
pgsql.allow_persistent = On
pgsql.auto_reset_persistent = Off
pgsql.max_persistent = -1
pgsql.max_links = -1
pgsql.ignore_notice = 0
pgsql.log_notice = 0
[Sybase-CT]
sybct.allow_persistent = On
sybct.max_persistent = -1
sybct.max_links = -1
sybct.min_server_severity = 10
sybct.min_client_severity = 10
[Session]
session.save_handler = files
session.use_strict_mode = 0
session.use_cookies = 1
session.use_only_cookies = 1
session.name = S
session.auto_start = 0
session.cookie_lifetime = 0
session.cookie_path = /
session.cookie_domain =
session.cookie_httponly =
session.serialize_handler = php
session.gc_probability = 0
session.gc_divisor = 1000
session.gc_maxlifetime = 1440
session.referer_check =
session.cache_limiter = nocache
session.cache_expire = 180
session.use_trans_sid = 0
session.hash_function = 0
session.hash_bits_per_character = 5
url_rewriter.tags = "a=href,area=href,frame=src,input=src,form=fakeentry"
[MSSQL]
mssql.allow_persistent = On
mssql.max_persistent = -1
mssql.max_links = -1
mssql.min_error_severity = 10
mssql.min_message_severity = 10
mssql.compatibility_mode = Off
mssql.secure_connection = Off
[soap]
soap.wsdl_cache_enabled=1
soap.wsdl_cache_dir="/tmp"
soap.wsdl_cache_ttl=86400
soap.wsdl_cache_limit = 5
]]
	if php.debug then
		PHPINI = PHPINI .. "[xdebug]\n"
		PHPINI = PHPINI .. "zend_extension=xdebug.so\n"
		PHPINI = PHPINI .. "xdebug.default_enable=1\n"
		PHPINI = PHPINI .. "xdebug.default_enable=1\n"
		PHPINI = PHPINI .. "xdebug.force_display_errors=1\n"
		PHPINI = PHPINI .. "xdebug.remote_enable=On\n"
		PHPINI = PHPINI .. "xdebug.remote_connect_back=1\n"
		PHPINI = PHPINI .. "xdebug.remote_host=localhost\n"
		PHPINI = PHPINI .. "xdebug.remote_port=9000\n"
	end
	write_file("./etc/php5/fpm/php.ini", PHPINI)
	write_file("./etc/php5/cli/php.ini", PHPINI)
	write_file("./etc/php5/cgi/php.ini", PHPINI)
	return 0
end

function background()
	print("Starting PHP.")
	exec("mkdir /run/php; /usr/sbin/php-fpm7.0 &")
	return 0
end

Mount{ path='/var/log/', type="map", source="log" }
Mount{ path='/var/run/', type="map", source=".run" }
Mount{ path='/var/lib/php/sessions', type="tmpfs", size="512M" }

if caddy then caddy:AddFastCGI{ext='php',socket='/run/php/php7.0-fpm.sock'} end
if nginx then nginx:AddFastCGI{ext='php',socket='/run/php/php7.0-fpm.sock'} end
