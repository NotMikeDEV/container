#!/usr/local/sbin/container
---Owncloud server.
enable_debug(nil) -- Remove this line for production.

require("module/caddy")
require("module/php")
require("module/mysql")
require("module/owncloud")
require("module/autoip")
autoip:AssignIP("owncloud", 2)

mysql:Database{database='owncloud'}:Grant{user='owncloud',password='owncloud'}

local TestSite = caddy:AddWebsite(owncloud:Instance{hostname=':8001', root='/owncloud/test'})
TestSite:AddWebsocket{source='/cat', target='/bin/cat'}