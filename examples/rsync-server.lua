#!/usr/local/sbin/container
---Basic RSync server.
enable_debug(nil) -- Remove this line for production.

require("module/network")
require("module/rsync")
enable_debug(nil)

--Add NATED IPv4 and IPv6
network:AddIP{ipv4='100.99.77.1', ipv6='fc00::99:77:1', nat=true}
local RSyncServer = rsync:AddServer(12345)
local RSyncDir = RSyncServer:AddDir{path='test', localpath='/rsync/'}
RSyncDir:AddUser{username='test', password='test'}
--Make /root persistent.
Mount{ path='/rsync', type="map", source="../rsync" }
