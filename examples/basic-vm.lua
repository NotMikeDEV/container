#!/usr/sbin/container

filesystem["/root/"] = { type="map", path="root" }
request_IP("10.0.0.2")
request_IP("2001:470:3922::c")
