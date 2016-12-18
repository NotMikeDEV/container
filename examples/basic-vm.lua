#!/usr/local/sbin/container
---Basic container with own network.
enable_debug(nil) -- Remove this line for production.

require("module/sshd")
require("module/autoip")
autoip:AssignIP("basic-vm", 1)

--Set SSH root password.
sshd:SetRootPassword("securepasswordxkcd")

--Make /root persistent.
Mount{ path='/root', type="map", source="root" }
