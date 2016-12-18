#!/bin/bash
../examples/wordpress.lua restart || exit 1
. ./autoip.sh wordpress

RET=1
let END=$(date +"%s")+30
while [ $END -gt $(date +"%s") ]; do
	wget -T 2 -o /dev/stdout -O /dev/null "http://$IPv4:8002/readme.html" && wget -T 2 -o /dev/stdout -O /dev/null "http://[$IPv6]:8002/readme.html"
	RET=$?
	echo $RET
	if [ $RET == 0 ]; then exit 0; fi #200 OK.
	sleep 0.3
done
echo "Tests failed."
exit 1