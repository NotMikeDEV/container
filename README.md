# Linux Container Building System

## Dependencies
Lua requires readline library (libreadline-dev).
Container building requires debootstrap.
In theory if you have debootstrap and other required tools it should work on any linux kernel with namespace support, but only Debian is supported.

## Debian Install from source
    apt-get install build-essential git debootstrap libreadline-dev
    git clone https://github.com/notmike-uk/container.git
    cd container
    make install

## Done
Get it working

## Todo
WTFM

## Quick Overview
This is basically a glorified wrapper around the linux namespaces functionality, which is pretty much “chroot on steroids”.

It creates a virtual file system which gets mounted read-only, apart from specific directories that get mapped to folders outside the container root. When an application launches it only sees its own filesystem, PID 1 is the container host process and it won’t see processes running outside the container.

When network isolation is used the application also gets its own network interface and loopback and does not see the host network interfaces, instead its IP traffic is routed via a virtual adaptor connected to the host.

The configuration script is run through a Turing complete interpreter, so should be infinitely extendable.

#### It is designed for packaging applications/services, and is not by itself a security measure.
Things in the container run as root, and there is no way to prevent root breaking out of a jail. Because of this no attempt has been made to "lock down the container". Any security measures would not hinder a determined attacker but may cause issues for legitimate applications, therefore full host access is considered a feature for convenience.
