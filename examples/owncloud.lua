#!/usr/sbin/container
require("templates/caddy")
require("templates/php")
require("templates/mysql")
require("templates/owncloud")

request_IP("10.0.0.2", {nat=true})
request_IP("2001:470:3922::1:7239", {nat=true})

mysql.password = "owncloud987"

local TestSite = caddy:AddWebsite(owncloud:Instance{hostname='owncloud.offsite.notmike.uk'})
