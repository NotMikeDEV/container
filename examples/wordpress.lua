#!/usr/local/sbin/container
---Wordpress server.
enable_debug(nil) -- Remove this line for production.

require("module/caddy")
require("module/php")
require("module/mysql")
require("module/wordpress")
require("module/autoip")
autoip:AssignIP("wordpress", 3)

local TestSite = caddy:AddWebsite(wordpress:Instance{hostname=':8002', root='/wordpress/test'})
