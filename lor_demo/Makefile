# CFG = conf/config.lor.json
PORT = 8890
SOCK = /usr/local/var/run/unit/control.sock

CONF_LUA = conf/config.lor.lua
CONF = `./$(CONF_LUA) -j -u`

help:
	@echo "make: restart, start, stop, config, get"
	@echo PORT: $(PORT)
	@echo SOCK: $(SOCK)
	@echo CONF: $(CONF)

restart:
	pkill unitd
	unitd

start:
	unitd

stop:
	pkill unitd

# config:
# 	curl -X PUT \
# 		--data-binary @$(CFG) \
# 		--unix-socket $(SOCK) \
# 		http://localhost:$(PORT)/config/
config:
	curl -X PUT \
		--data-binary $(CONF) \
		--unix-socket $(SOCK) \
		http://localhost:$(PORT)/config/

get:
	curl 'http://localhost:$(PORT)/'