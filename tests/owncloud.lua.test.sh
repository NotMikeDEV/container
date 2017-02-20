#!/bin/bash
../examples/owncloud.lua restart || exit 1
. ./autoip.sh owncloud

RET=1
let END=$(date +"%s")+20
while [ $END -gt $(date +"%s") ]; do
	wget -T 2 -o /dev/stdout -O /dev/null "http://[$IPv6]:8001/index.php" && wget -T 2 -o /dev/stdout -O /dev/null "http://$IPv4:8001/index.php"
	RET=$?
	echo $RET
	if [ $RET == 0 ]; then ( ../examples/owncloud.lua stop; exit 0 ) ; fi #200 OK.
	sleep 0.3
done
echo "Tests failed."

exit 1
