#!/bin/bash

run_test() {
	TEMPFILE=$(tempfile)
	echo -n "$@"
	$@
	RESULT=$?
	if [ ! $RESULT == 0 ]; then
		echo
		echo "$@ Failed."
		cd $ORIGINAL_PATH
		exit 1
	fi
	echo " Done."
	rm -f $TEMPFILE
	return 0
}

MY_PATH=`dirname $0`
ORIGINAL_PATH=`pwd`
cd $MY_PATH
echo "#Test Subnet" >./ip.conf
echo "" >>./ip.conf
echo "fd00:0420:0042:4200:0:0:0:0" >>./ip.conf
echo "100.67.0.0" >>./ip.conf

for file in *.test.sh; do
	run_test ./$file
done
rm -rf ./ip.conf
cd $ORIGINAL_PATH
exit 0
