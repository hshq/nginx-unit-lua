#ifndef LIB_NGINX_UNIT_H
#define LIB_NGINX_UNIT_H

// NOTE hsq 在 Makefile 中选择是否定义 NXT_DEBUG
// #define NXT_DEBUG 1
#include <nxt_unit.h>
#include <nxt_unit_request.h>

#include <lua.h>
#include <lauxlib.h>

#include <adapter.h>


#define MT_CONTEXT "lnginx-unit.context"
#define MT_REQUEST "lnginx-unit.request"

#define NXT_UNIT_HASH_HOST 0xE6EB

#define GET_STR(p) (const char *)nxt_unit_sptr_get(p)


#define RETURN_ERR_LITERAL(msg) \
    lua_pushboolean(L, False); \
    lua_pushinteger(L, NXT_UNIT_ERROR); \
    lua_pushliteral(L, msg); \
    return 3
#define RETURN_ERR_FSTRING(fmt, ARGS...) \
    lua_pushboolean(L, False); \
    lua_pushinteger(L, NXT_UNIT_ERROR); \
    lua_pushfstring(L, fmt, ##ARGS); \
    return 3
#define RETURN_RC(rc) \
    lua_pushboolean(L, NXT_UNIT_OK == (rc)); \
    lua_pushinteger(L, rc); \
    return 2

#define REF2PTR(ref) ((void *)(ptrdiff_t)ref)
#define PTR2REF(ptr) ((int)   (ptrdiff_t)ptr)


typedef struct context_s {
    nxt_unit_ctx_t *ctx;
} context_t;

typedef struct request_s {
    nxt_unit_request_t *req;
} request_t;


// NOTE hsq 用函数封装则传入的 luaL_Reg[] 变成指针后无法取得项目数。
#define new_meta(mt_name, mt, mtds) { \
    if (!luaL_newmetatable(L, mt_name)) { \
        nxt_unit_alert(NULL, "注册元表 %s 失败！已经注册。", mt_name); \
    } \
    luaL_setfuncs(L, mt, 0); \
    luaL_newlib(L, mtds); \
    lua_setfield(L, -2, "__index"); \
    lua_pop(L, 1); \
}


LUAMOD_API int luaopen_unit_core(lua_State *);
LUAMOD_API void reg_ctx(lua_State *);
LUAMOD_API void reg_req(lua_State *);

LUAMOD_API int lib_func_init(lua_State *);
LUAMOD_API int lib_func_log(lua_State *);
LUAMOD_API int lib_func_table_new(lua_State *);

LUAMOD_API int ctx_mtd_run(lua_State *);
LUAMOD_API int ctx_mtd_done(lua_State *);
LUAMOD_API int ctx_mtd_log(lua_State *);
LUAMOD_API int ctx_mtd_alert(lua_State *);
LUAMOD_API int ctx_mtd_err(lua_State *);
LUAMOD_API int ctx_mtd_warn(lua_State *);
LUAMOD_API int ctx_mtd_notice(lua_State *);
LUAMOD_API int ctx_mtd_info(lua_State *);
LUAMOD_API int ctx_mtd_debug(lua_State *);

LUAMOD_API int req_mtd_fields(lua_State *);

void request_handler(nxt_unit_request_info_t *);

#endif // LIB_NGINX_UNIT_H
