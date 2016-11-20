#!/bin/bash
../examples/nat64-gateway.lua restart || exit 1

ping -c 1 -w 5 100.99.98.64 || exit 1
ping6 -c 1 -w 5 fd64::100.99.98.64 || exit 1
echo
let END=$(date +"%s")+10
while [ $END -gt $(date +"%s") ]; do
	DNS=`nslookup -retry=1 -timeout=1 -query=AAAA ipv4.google.com 100.99.98.64 | grep "fd64::" | grep "has AAAA address"`
	if [ ! "$DNS" == "" ]; then
		echo $DNS
		echo
		ping6 -c 1 -w 5 fd64::8.8.8.8 || exit 1
		exit 0
	else
		echo "DNS lookup failed."
	fi
done

echo "Tests complete."
exit 0