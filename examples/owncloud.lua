#!/usr/local/sbin/container
---Owncloud server.
require("module/caddy")
require("module/php")
require("module/mysql")
require("module/owncloud")

mysql:Database{database='owncloud'}:Grant{user='owncloud',password='owncloud'}

local TestSite = caddy:AddWebsite(owncloud:Instance{hostname=':8001', root='/owncloud/test'})
