#!/usr/sbin/container
require("templates/caddy")
require("templates/php")
require("templates/mysql")
require("templates/owncloud")

request_IP("10.0.0.2", {nat=true})
request_IP("2001:470:3922::1:1627", {nat=true})

mysql:Database{database='owncloud'}:Grant{user='owncloud',password='owncloud'}

local TestSite = caddy:AddWebsite(owncloud:Instance{hostname='owncloud.offsite.notmike.uk'})
