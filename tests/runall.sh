#!/bin/bash

run_test() {
	TEMPFILE=$(tempfile)
	echo -n "$@"
	$@ > $TEMPFILE 2>&1
	RESULT=$?
	if [ ! $RESULT == 0 ]; then
		echo
		cat $TEMPFILE
		rm -f $TEMPFILE
		echo "$@ Failed. Returned $RESULT"
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
for file in *.test.sh; do
	run_test ./$file
done
cd $ORIGINAL_PATH
exit 0
