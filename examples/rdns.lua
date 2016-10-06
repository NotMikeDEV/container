#!/usr/sbin/container
require("templates/bind")

request_IP("10.0.1.53", {nat=true})
request_IP("2001:470:3922::2:53")
