#!/usr/sbin/container
require("templates/caddy")
require("templates/php")
require("templates/mysql")

request_IP("10.0.0.3", {nat=true})
request_IP("2001:470:3922::1:4325", {nat=true})

mysql.password = "password"

local TestSite = webserver:AddWebsite{hostname='test.offsite.notmike.uk'}
local RedirectSite = webserver:AddWebsite{hostname='redirect.offsite.notmike.uk'}
RedirectSite:AddRedirect{source='/(.*)', target='https://test.offsite.notmike.uk/$1', status=302}
