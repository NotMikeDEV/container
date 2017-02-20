#!/bin/bash
../examples/docs_www.lua restart || exit 1
mkdir -p ../doc/
chmod 0777 ../doc/
echo Test > ../doc/test.txt
chmod 0777 ../doc/test.txt

let END=$(date +"%s")+30
while [ $END -gt $(date +"%s") ]; do
	wget -T 2 -o /dev/stdout -O /dev/null "http://127.0.0.1:8000/test.txt"
	RET=$?
	echo $RET
	if [ $RET == 0 ]; then ../examples/docs_www.lua stop ; exit 0; fi #200 OK.
	sleep 0.3
done
echo "Tests failed."
rm -f ../doc/test.txt
exit 1
