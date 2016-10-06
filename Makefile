CC=gcc
CFLAGS=-I.
INSTALL_PATH=/usr/sbin

container: lua/liblua.a defaultlua.o
	$(CC) container.c lua/liblua.a defaultlua.o -o container -ldl -lm

all: container container-src.tar.gz

lua/liblua.a:
	$(MAKE) -C lua linux

defaultlua.o:
	ld -r -b binary -o defaultlua.o container.lua

clean:
	-rm -f defaultlua.o container container-src.tar.gz
	-if [ -f /usr/sbin/container ]; then \
		for script in examples/.*.lua; do \
			(kill -s 9 `cat $$script/.pid`); \
			sleep 1; \
			(rm -rf $$script); \
		done \
	fi
	$(MAKE) -C lua clean

install: container
	cp container ${INSTALL_PATH}
	mkdir -p /etc/container/templates/
	cp -R examples/templates/* /etc/container/templates/

install_examples: install
	cp -R examples/* /etc/container/

src: container-src.tar.gz

container-src.tar.gz:
	tar -zcf container-src.tar.gz --transform 's,^,container/,' container.c container.lua README.md LICENSE examples/*.lua lua/*.c lua/*.h Makefile lua/Makefile
