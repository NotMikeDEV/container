php={}

function install_container()
	print("Installing PHP.")
	install_package("php5-fpm php5-cli php5-gd php5-curl php5-sqlite php5-mysql php5-odbc php5-imap php5-mhash php5-memcached php5-ssh2 php5-xcache")
	return 0
end

function run()
	print("Starting PHP.")
	exec("/usr/sbin/php5-fpm &")
	return 0
end

if not filesystem['/var/log/'] then filesystem['/var/log/'] = { type="map", path="log" } end
if not filesystem['/var/run/'] then filesystem['/var/run/'] = { type="map", path=".run" } end
if not filesystem['/var/lib/php5/sessions'] then filesystem['/var/lib/php5/sessions'] = { type="tmpfs", size="512M" } end

if webserver then webserver:AddFastCGI{ext='php',socket='/var/run/php5-fpm.sock'} end
