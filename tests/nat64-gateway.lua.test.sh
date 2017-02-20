#!/bin/bash
../examples/nat64-gateway.lua restart || exit 1
. ./autoip.sh nat64

ping -c 1 -w 5 $IPv4 || exit 1
ping6 -c 1 -w 5 $IPv6_PREFIX || exit 1
echo
let END=$(date +"%s")+10
while [ $END -gt $(date +"%s") ]; do
	DNS=`nslookup -retry=1 -timeout=1 -query=AAAA ipv4.google.com $IPv4 | grep ":A:64:" | grep "has AAAA address"`
	if [ ! "$DNS" == "" ]; then
		echo $DNS
		echo
		ping6 -c 1 -w 5 `echo $IPv6_PREFIX | cut -d ":" -f 1,2,3,4,5,6`:8.8.8.8 || exit 1
		exit 0
	else
		echo "DNS lookup failed."
	fi
done

../examples/nat64-gateway.lua stop || exit 1
echo "Tests complete."
exit 0