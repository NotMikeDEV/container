#!/usr/local/sbin/container
---Simple web proxy.
require("module/nginx")

--Add webserver.
local DebianRepo = nginx:AddWebsite{hostname='debian.linuxship.net'}
DebianRepo:AddProxy{source='/', target='http://127.0.0.1:3142/ftp.us.debian.org/'}
local DebianRepo2 = nginx:AddWebsite{hostname=':8081'}
DebianRepo2:AddProxy{source='/', target='https://www.google.com/', hostname='www.google.com'}

--Map path to doc directory.
Mount{ path="/var/www/", type="map", source="../../doc" }
