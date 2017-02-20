#!/bin/bash
../examples/tinc-router.lua restart || exit 1
../examples/tinc-vm.lua restart || exit 1
. ./autoip.sh tinc
IPv4=$(echo $IPv4_PREFIX | cut -d "." -f 1,2,3).6
IPv6=$(echo $IPv6_PREFIX | cut -d ":" -f 1,2,3,4,5,6,7):6
sleep 5

ping -c 1 -w 5 $IPv4 || exit 1
ping6 -c 1 -w 5 $IPv6 || exit 1

if [ ! -f ~/.ssh/id_rsa.pub ]; then
	ssh-keygen -f ~/.ssh/id_rsa -N ''
fi
MYKEY=$(cat ~/.ssh/id_rsa.pub)
mkdir -p ../examples/.tinc-vm.lua/root/.ssh/
EXISTINGKEYS=$(cat ../examples/.tinc-vm.lua/root/.ssh/authorized_keys | grep -v "$MYKEY")
echo $EXISTINGKEYS > ../examples/.tinc-vm.lua/root/.ssh/authorized_keys
echo $MYKEY >> ../examples/.tinc-vm.lua/root/.ssh/authorized_keys
echo "SSH IPv4"
ssh -i ~/.ssh/id_rsa -o StrictHostKeyChecking=no $IPv4 exit 0 >/dev/null 2>&1 || exit 1
echo "SSH IPv6"
ssh -i ~/.ssh/id_rsa -o StrictHostKeyChecking=no $IPv6 exit 0 >/dev/null 2>&1 || exit 1

../examples/tinc-router.lua stop || exit 1
../examples/tinc-vm.lua stop || exit 1
echo "Tests complete."
exit 0