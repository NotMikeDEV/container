#!/bin/bash

do_containers() {
	echo "./$1 $2"
	OUTPUT=`./$1 $2 2>&1`
	RESULT=$?
	if [ $RESULT == 158 ]; then # "Already running"
		echo $OUTPUT
		RESULT=0
	fi
	if [ ! $RESULT == 0 ]; then
		echo $OUTPUT
		echo "$1 Failed to $2. Returned $RESULT"
		cd $ORIGINAL_PATH
		exit 1
	fi
	return 0
}

MY_PATH=`dirname $0`
ORIGINAL_PATH=`pwd`
cd $MY_PATH
for file in *.lua; do
	do_containers $file $1
done
cd $ORIGINAL_PATH
exit 0
