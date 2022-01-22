#include "lib-nginx-unit.h"


LUAMOD_API int LUA_RIDX_STR_FORMAT;


#define GET_CTX(_var, index) \
    _var = luaL_checkudata(L, index, MT_CONTEXT); \
    if (!_var->ctx) { \
        RETURN_ERR_LITERAL("上下文已失效！"); \
    }

LUAMOD_API int ctx_mtd_run(lua_State *L) {
    int rc;
    context_t *uctx;

    GET_CTX(uctx, 1);
    rc = nxt_unit_run(uctx->ctx);

    RETURN_RC(rc);
}

LUAMOD_API int ctx_mtd_done(lua_State *L) {
    context_t *uctx;

    GET_CTX(uctx, 1);
    nxt_unit_done(uctx->ctx);
    luaL_unref(L, LUA_REGISTRYINDEX, PTR2REF(uctx->ctx->data));
    // lua_pushnil(L);
    // lua_setiuservalue(L, 1, 1);

    RETURN_RC(NXT_UNIT_OK);
}

LUAMOD_API int ctx_mtd_log(lua_State *L) {
    int level;
    context_t *uctx;

    GET_CTX(uctx, 1);
    level = luaL_checkinteger(L, 2);
    if (NXT_UNIT_LOG_ALERT > level || level > NXT_UNIT_LOG_DEBUG) {
        nxt_unit_log(uctx->ctx, NXT_UNIT_LOG_ALERT,
            "无效 LEVEL %d❎ [%d, %d]✅！",
                level, NXT_UNIT_LOG_ALERT, NXT_UNIT_LOG_DEBUG);
    }

    lua_rawgeti(L, LUA_REGISTRYINDEX, LUA_RIDX_STR_FORMAT);
    lua_replace(L, 2);
    lua_call(L, lua_gettop(L) - 2, 1);
    nxt_unit_log(uctx->ctx, level, "%s", lua_tostring(L, -1));

    return 0;
}

#define def_ctx_mtd_log_(name, NAME) \
LUAMOD_API int ctx_mtd_##name(lua_State *L) { \
    lua_pushinteger(L, NXT_UNIT_LOG_##NAME); \
    lua_insert(L, 2); \
    return ctx_mtd_log(L); \
}
def_ctx_mtd_log_(alert,  ALERT)
def_ctx_mtd_log_(err,    ERR)
def_ctx_mtd_log_(warn,   WARN)
def_ctx_mtd_log_(notice, NOTICE)
def_ctx_mtd_log_(info,   INFO)
def_ctx_mtd_log_(debug,  DEBUG)


static const luaL_Reg ctx_mtds[] = {
    {"run",     ctx_mtd_run},
    {"done",    ctx_mtd_done},
    {"log",     ctx_mtd_log},
    {"alert",   ctx_mtd_alert},
    {"err",     ctx_mtd_err},
    {"warn",    ctx_mtd_warn},
    {"notice",  ctx_mtd_notice},
    {"info",    ctx_mtd_info},
    {"debug",   ctx_mtd_debug},
    {NULL,      NULL}
};

// metamethods for context
static const luaL_Reg ctx_meta_mtds[] = {
    {"__index",    NULL}, /* place holder */
    {"__gc",       ctx_mtd_done},
    {NULL,         NULL}};


LUAMOD_API void reg_ctx(lua_State *L) {
    new_meta(MT_CONTEXT, ctx_meta_mtds, ctx_mtds);
}
