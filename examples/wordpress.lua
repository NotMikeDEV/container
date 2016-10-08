#!/usr/sbin/container
require("templates/caddy")
require("templates/php")
require("templates/mysql")
require("templates/wordpress")

request_IP("10.0.0.4", {nat=true})
request_IP("2001:470:3922::1:8193", {nat=true})

mysql.password = "wordpress987"

local TestSite = caddy:AddWebsite(wordpress:Instance{hostname = 'wordpress.offsite.notmike.uk'})
