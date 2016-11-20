CC=gcc
CFLAGS=-I.
INSTALL_PATH=/usr/sbin

all: container doc

PREFIX = /usr/local
LOGGING_LUAS= lualogging/src/logging/console.lua lualogging/src/logging/email.lua lualogging/src/logging/file.lua lualogging/src/logging/rolling_file.lua lualogging/src/logging/socket.lua lualogging/src/logging/sql.lua
LOGGING_ROOT_LUAS= lualogging/src/logging.lua 
LUA_DIR= $(PREFIX)/lib/lua/5.3
INSTALL_PATH=$(PREFIX)/sbin

$(PREFIX)/lib/liblua.a: $(PREFIX)/bin/lua

$(PREFIX)/bin/lua:
	-git clone --depth 1 https://github.com/lua/lua.git
	$(MAKE) -C lua linux install
	rm -rf lua

$(LUA_DIR)/ldoc.lua:
	@echo "Run $(MAKE) install_ldoc to install LDoc first."
	@false

install_ldoc: $(PREFIX)/bin/lua $(LUA_DIR)/pl $(LUA_DIR)/lfs.so
	-git clone --depth 1 https://github.com/stevedonovan/LDoc.git
	mkdir -p $(LUA_DIR)/ldoc
	cp -r LDoc/ldoc/* $(LUA_DIR)/ldoc
	cp LDoc/ldoc.lua $(LUA_DIR)
	rm -rf LDoc

$(LUA_DIR)/pl: $(PREFIX)/bin/lua
	-git clone --depth 1 https://github.com/stevedonovan/Penlight.git
	mkdir -p $(LUA_DIR)/pl
	cp -r Penlight/lua/pl/* $(LUA_DIR)/pl
	rm -rf Penlight

$(LUA_DIR)/lfs.so: $(PREFIX)/bin/lua
	-git clone --depth 1 https://github.com/keplerproject/luafilesystem.git
	cp lfsconf luafilesystem/config
	$(MAKE) -C luafilesystem src/lfs.so install
	rm -rf luafilesystem

${INSTALL_PATH}/container: container
	-rm -f ${INSTALL_PATH}/container
	cp container ${INSTALL_PATH}
	mkdir -p $(PREFIX)/container/module/
	cp -R module/* $(PREFIX)/container/module/

container: $(PREFIX)/lib/liblua.a defaultlua.o
	$(CC) container.c -llua defaultlua.o -o container -ldl -lm

doc/index.html: $(LUA_DIR)/ldoc.lua
	$(PREFIX)/bin/lua $(LUA_DIR)/ldoc.lua -p container -f markdown .
	chmod +xr doc/ -R

doc: doc/index.html

doc_server: doc/index.html ${INSTALL_PATH}/container
	./examples/docs_www.lua restart
	@echo "The documentation can be accessed via http://127.0.0.1:8000/"

defaultlua.o:
	ld -r -b binary -o defaultlua.o container.lua

clean:
	-rm -rf defaultlua.o container doc/* lua LDoc luafilesystem Penlight
	-./examples/all.sh clean
	-rm -rf examples/.*lua
	-chmod 0764 . -R

install:
	-rm -f ${INSTALL_PATH}/container
	$(MAKE) ${INSTALL_PATH}/container

test: ${INSTALL_PATH}/container
	./tests/runall.sh
	@echo "Testing Complete. Seems fine."
	
rebuild:
	-rm -rf defaultlua.o container
	-rm ${INSTALL_PATH}/container
	$(MAKE) container

autostart: install
	cp autostart-container /etc/init.d/
	update-rc.d autostart-container defaults
	update-rc.d autostart-container enable
