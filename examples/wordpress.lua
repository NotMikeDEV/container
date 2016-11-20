#!/usr/local/sbin/container
---Wordpress server.
require("module/caddy")
require("module/php")
require("module/mysql")
require("module/wordpress")

local TestSite = caddy:AddWebsite(wordpress:Instance{hostname=':8002', root='/wordpress/test'})
