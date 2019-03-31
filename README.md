# Linux Container Building System
Project Status: Pre-Pre-Pre-Alpha. I am actively developing the codebase and do push changes before testing them properly. Do not be surprised if an update deletes the entire contents of your server.

## Dependencies
Requires readline library (libreadline-dev).
Container building requires debootstrap.
Tinc networking requires tinc on the host.
In theory if you have debootstrap and other required tools it should work on any linux kernel with namespace support, but only Debian is supported.

## Debian Install
	apt install -y build-essential git debootstrap libreadline-dev tinc && \
	git clone https://github.com/NotMikeDEV/container.git && \
	cd container && \
	make install

## Docs
Run 'make doc' to compile the documentation using LDoc.

Run 'make doc_server' to launch a web server on port 8092 containing the documentation.

Or browse the online documentation at https://notmikeuk.github.io/container-doc/

## Quick Overview
This is basically a glorified wrapper around the linux namespaces functionality, which is pretty much “chroot on steroids”.

It creates a virtual file system which gets mounted read-only, apart from specific directories that get mapped to folders outside the container root. When an application launches it only sees its own filesystem, PID 1 is the container host process and it won’t see processes running outside the container.

When network isolation is used the application also gets its own network interface and loopback and does not see the host network interfaces, instead its IP traffic is routed via a virtual adaptor connected to the host.

The configuration script is run through a Turing complete interpreter, so should be infinitely extendable.

#### It is designed for packaging applications/services, and is not by itself a security measure.
Things in the container run as root, and there is no way to prevent root breaking out of a jail. Because of this no attempt has been made to "lock down the container". Any security measures would not hinder a determined attacker but may cause issues for legitimate applications, therefore full host access is considered a feature for convenience.
