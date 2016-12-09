#!/bin/bash
../examples/tinc-router.lua restart || exit 1
../examples/tinc-vm.lua restart || exit 1

sleep 5

ping -c 1 -w 5 100.100.0.2 || exit 1
ping6 -c 1 -w 5 fcfc::2 || exit 1

if [ ! -f ~/.ssh/id_rsa.pub ]; then
	ssh-keygen -f ~/.ssh/id_rsa -N ''
fi
MYKEY=$(cat ~/.ssh/id_rsa.pub)
mkdir -p ../examples/.tinc-vm.lua/root/.ssh/
EXISTINGKEYS=$(cat ../examples/.tinc-vm.lua/root/.ssh/authorized_keys | grep -v "$MYKEY")
echo $EXISTINGKEYS > ../examples/.tinc-vm.lua/root/.ssh/authorized_keys
echo $MYKEY >> ../examples/.tinc-vm.lua/root/.ssh/authorized_keys
echo "SSH IPv4"
ssh -i ~/.ssh/id_rsa -o StrictHostKeyChecking=no 100.100.0.2 exit 0 >/dev/null 2>&1 || exit 1
echo "SSH IPv6"
ssh -i ~/.ssh/id_rsa -o StrictHostKeyChecking=no fcfc::2 exit 0 >/dev/null 2>&1 || exit 1

echo "Tests complete."
exit 0