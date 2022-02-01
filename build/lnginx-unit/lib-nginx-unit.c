#define lib_nginx_unit_c
#define LUA_LIB

#include <lualib.h>
#include <assert.h>

#include "lib-nginx-unit.h"


static boolean_t inited = False;
int LUA_RIDX_STR_FORMAT = LUA_NOREF;


LUAMOD_API int lib_func_init(lua_State *L) {
    nxt_unit_init_t init = {0};
    context_t *uctx;
    int rc;

    if (inited) {
        RETURN_ERR_LITERAL("不可重复初始化！");
    }

    luaL_checktype(L, 1, LUA_TFUNCTION);

    uctx = lua_newuserdatauv(L, sizeof(context_t), 1);
    uctx->ctx = NULL; // __gc 和 __close 依赖
    lua_pushvalue(L, 1);
    rc = lua_setiuservalue(L, -2, 1);
    if (!rc) {
        RETURN_ERR_LITERAL("设置请求处理函数失败！");
    }
    luaL_setmetatable(L, MT_CONTEXT);

    init.callbacks.request_handler = request_handler;
    // main_ctx.unit.data = L
    init.data = L;
    // main_ctx.data == uctx 的引用
    lua_pushvalue(L, -1);
    init.ctx_data = REF2PTR(luaL_ref(L, LUA_REGISTRYINDEX));
    uctx->ctx = nxt_unit_init(&init);
    if (!uctx->ctx) {
        RETURN_ERR_LITERAL("初始化失败！");
    }

    inited = True;

    return 1;
}

LUAMOD_API int lib_func_log(lua_State *L) {
    int level = luaL_checkinteger(L, 1);
    const char *msg = luaL_checkstring(L, 2);

    nxt_unit_log(NULL, level, "%s", msg);
    return 0;
}


LUAMOD_API int lib_func_table_new(lua_State *L) {
    int narr = luaL_checkinteger(L, 1);
    int nrec = luaL_checkinteger(L, 2);

    narr = narr > 0 ? narr : 0;
    nrec = nrec > 0 ? nrec : 0;
    lua_createtable(L, narr, nrec);
    return 1;
}


static const luaL_Reg lib_funcs[] = {
    {"init",      lib_func_init},
    {"log",       lib_func_log},

    {"table_new", lib_func_table_new},
    /* placeholders */
    {"VERSION",    NULL},
    {"VERNUM",     NULL},
    {"INIT_ENV",   NULL},
    // {"NONE_FIELD", NULL},
    {"RC",         NULL},
    {"LOG_LEVEL",  NULL},
    {NULL,         NULL}
};

static const char *RCs[] = {
    "OK", "ERROR", "AGAIN", "CANCELLED"
};

static const char *LOG_LEVELs[] = {
    "ALERT", "ERR", "WARN", "NOTICE", "INFO", "DEBUG"
};


LUAMOD_API int luaopen_unit_core(lua_State *L) {
    luaL_newlib(L, lib_funcs);

    // 注册 unit 的一些参数常量
    lua_pushliteral(L, NXT_UNIT_INIT_ENV);
    lua_setfield(L, -2, "INIT_ENV");

    lua_pushliteral(L, NXT_VERSION);
    lua_setfield(L, -2, "VERSION");
    lua_pushinteger(L, NXT_VERNUM);
    lua_setfield(L, -2, "VERNUM");

    // lua_pushinteger(L, NXT_UNIT_NONE_FIELD);
    // lua_setfield(L, -2, "NONE_FIELD");

    // 注册缺省配置表
    lua_createtable(L, 0, 8);
    #define SET_DEFAULT_CONFIG(KEY) \
        lua_pushliteral(L, #KEY); lua_pushstring(L, NXT_##KEY); lua_rawset(L, -3)
    SET_DEFAULT_CONFIG(PID);
    SET_DEFAULT_CONFIG(LOG);
    SET_DEFAULT_CONFIG(MODULES);
    SET_DEFAULT_CONFIG(STATE);
    SET_DEFAULT_CONFIG(TMP);
    SET_DEFAULT_CONFIG(CONTROL_SOCK);
    SET_DEFAULT_CONFIG(USER);
    SET_DEFAULT_CONFIG(GROUP);
    #undef SET_DEFAULT_CONFIG
    lua_setfield(L, -2, "DEFAULT_CONFIG");

    // 注册返回代码表
    lua_createtable(L, NXT_UNIT_CANCELLED + 1, NXT_UNIT_CANCELLED + 1);
    for (int i = 0; i <= NXT_UNIT_CANCELLED; i++) {
        lua_pushstring(L, RCs[i]);
        lua_pushinteger(L, i);
        lua_rawset(L, -3);
        lua_pushstring(L, RCs[i]);
        lua_rawseti(L, -2, i);
    }
    lua_setfield(L, -2, "RC");

    // 注册日志等级表
    lua_createtable(L, NXT_UNIT_LOG_DEBUG + 1, NXT_UNIT_LOG_DEBUG + 1);
    for (int i = 0; i <= NXT_UNIT_LOG_DEBUG; i++) {
        lua_pushstring(L, LOG_LEVELs[i]);
        lua_pushinteger(L, i);
        lua_rawset(L, -3);
        lua_pushstring(L, LOG_LEVELs[i]);
        lua_rawseti(L, -2, i);
    }
    lua_setfield(L, -2, "LOG_LEVEL");

    // 注册 userdadta
    reg_ctx(L);
    reg_req(L);

    // 在注册表中缓存 string.format
    // int top = lua_absindex(L, -1);
    // luaL_openlibs(L);
    assert(luaL_dostring(L, "return string.format") == 0);
    // assert(ua_isfunction(L, -1));
    LUA_RIDX_STR_FORMAT = luaL_ref(L, LUA_REGISTRYINDEX);

    if (LUA_NOREF == LUA_RIDX_STR_FORMAT) {
        #define ERR_NEED_STR_FORMAT "log() 需要 string.format(fmt, ...) ！"
        nxt_unit_log(NULL, NXT_UNIT_LOG_ALERT, ERR_NEED_STR_FORMAT);
        luaL_error(L, ERR_NEED_STR_FORMAT);
    }
    // lua_settop(L, top);

    return 1;
}
