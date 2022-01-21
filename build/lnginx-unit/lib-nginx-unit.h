#ifndef LIB_NGINX_UNIT_H
#define LIB_NGINX_UNIT_H

#include <luaconf.h>
#include <lua.h>
#include <nxt_unit_request.h>

#include "../deps/adapter.h"

LUAMOD_API int luaopen_unit_core(lua_State *);

LUAMOD_API int lib_func_init(lua_State *);
LUAMOD_API int lib_func_log(lua_State *);
LUAMOD_API int lib_func_getpid(lua_State *);
LUAMOD_API int lib_func_getppid(lua_State *);

LUAMOD_API int ctx_mtd_run(lua_State *);
LUAMOD_API int ctx_mtd_done(lua_State *);
LUAMOD_API int ctx_mtd_log(lua_State *);
LUAMOD_API int ctx_mtd_alert(lua_State *);
LUAMOD_API int ctx_mtd_err(lua_State *);
LUAMOD_API int ctx_mtd_warn(lua_State *);
LUAMOD_API int ctx_mtd_notice(lua_State *);
LUAMOD_API int ctx_mtd_info(lua_State *);
LUAMOD_API int ctx_mtd_debug(lua_State *);

void request_handler(nxt_unit_request_info_t *);

#endif // LIB_NGINX_UNIT_H
