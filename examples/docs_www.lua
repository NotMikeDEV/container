#!/usr/local/sbin/container
---Simple web server to host the project documentation on port 8092.
require("module/nginx")

--Add webserver.
local TestSite = nginx:AddWebsite{hostname=':8000', root='/var/www'}

--Map path to doc directory.
Mount{ path="/var/www/", type="map", source="../../doc" }
