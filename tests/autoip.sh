#!/bin/sh
NAME=$1
IP_SUFFIX=`grep -v "^#" ./ip.conf | tail -n +4 | cut -d "." -f 1,2 | grep ".$NAME\$" | cut -d "." -f 1`
IPv6=`grep -v "^#" ./ip.conf | head -n 2 | tail -n 1 | cut -d ":" -f 1,2,3,4,5,6,7`
IPv6="${IPv6}:${IP_SUFFIX}"
IPv4=`grep -v "^#" ./ip.conf | head -n 3 | tail -n 1 | cut -d "." -f 1,2,3`
IPv4="${IPv4}.${IP_SUFFIX}"
IPv6_PREFIX=`grep -v "^#" ./ip.conf | head -n 2 | tail -n 1 | cut -d ":" -f 1,2,3,4`
IPv6_PREFIX=$IPv6_PREFIX:A:$IP_SUFFIX:0:0
IPv4_PREFIX=`grep -v "^#" ./ip.conf | head -n 3 | tail -n 1 | cut -d "." -f 1,2`
IPv4_PREFIX=$IPv4_PREFIX.$IP_SUFFIX.0
echo "name=$NAME"
echo "suffix=${IP_SUFFIX}"
echo "v6=$IPv6"
echo "v4=$IPv4"