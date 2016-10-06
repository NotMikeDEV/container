#!/usr/sbin/container
require("templates/bind")
require("templates/nat64")

request_IP("fc00::53", {nat=true})
nat64.ipv4="100.64.64.64"
nat64.prefix="64:ff9b::/96"
bind.nat64_prefix = nat64.prefix
