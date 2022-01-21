#define NXT_DEBUG 1
#include <nxt_unit.h>
#include <nxt_unit_request.h>

#define lib_nginx_unit_c
#define LUA_LIB

#include <lua.h>
#include <lauxlib.h>
#include <lualib.h>
#include <unistd.h>
#include <assert.h>

#include "lib-nginx-unit.h"
#include "../deps/adapter.h"

typedef enum boolean_e {
    False = 0,
    True,
} boolean_t;

typedef struct context_s {
    nxt_unit_ctx_t *ctx;
} context_t;

typedef struct request_s {
    nxt_unit_request_t *req;
} request_t;

// TODO hsq 把用户数据拆分出去？
#define MT_CONTEXT "lnginx-unit.context"
#define MT_REQUEST "lnginx-unit.request"

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
#define PTR2REF(ptr) ((int)(ptrdiff_t)ptr)

static boolean_t inited = False;
static int LUA_RIDX_STR_FORMAT = LUA_NOREF;


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

LUAMOD_API int lib_func_getpid(lua_State *L) {
    pid_t pid = getpid();
    lua_pushinteger(L, pid);
    return 1;
}

LUAMOD_API int lib_func_getppid(lua_State *L) {
    pid_t ppid = getppid();
    lua_pushinteger(L, ppid);
    return 1;
}


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


// @request userdata
// @max_fields int
// return len(fields), fields, flags
LUAMOD_API int req_mtd_fields(lua_State *L) {
    request_t          *ureq;
    nxt_unit_request_t *req;
    int                max_fields;
    // boolean_t          truncated = False;

    ureq = luaL_checkudata(L, 1, MT_REQUEST);
    req = ureq->req;
    if (!req) {
        RETURN_ERR_LITERAL("请求已失效！");
    }

    max_fields = luaL_checkinteger(L, 2);
    // if (0 < max_fields && max_fields < req->fields_count) {
    //     truncated = True;
    // } else {
    //     max_fields = req->fields_count;
    // }
    if (max_fields <= 0 || req->fields_count < (uint32_t)max_fields) {
        max_fields = req->fields_count;
    }

    lua_settop(L, 2);
    lua_createtable(L, 0, max_fields); // stack#3: fields
    lua_newtable(L);                   // stack#4: 0x01-skip, 0x02-hopbyhop
    for (uint32_t i = 0; i < (uint32_t)max_fields; i++) {
        nxt_unit_field_t *f = &req->fields[i];
        const char *name = (const char *)nxt_unit_sptr_get(&f->name);
        const char *value = (const char *)nxt_unit_sptr_get(&f->value);
        int flags = lua_getfield(L, 3, name);
        switch (flags) {
            case LUA_TSTRING: {
                lua_createtable(L, 2, 0);
                lua_insert(L, -2);
                lua_rawseti(L, -2, 1);
                lua_pushvalue(L, -1);
                lua_setfield(L, 3, name);
            }
            case LUA_TTABLE: {
                int len = lua_rawlen(L, -1);
                lua_pushlstring(L, value, f->value_length);
                lua_rawseti(L, -2, len + 1);
                lua_pop(L, 1);
                break;
            }
            default: {
                lua_pop(L, 1);
                lua_pushlstring(L, value, f->value_length);
                lua_setfield(L, 3, name);
                break;
            }
        }
        // TODO hsq skip 和 hopbyhop 如何处理？是否影响 max_fields ？
        // NOTE hsq fields_hopbyhop 只可能有：
        //      Connection Keep-Alive Proxy-Authenticate Proxy-Authorization
        //      Trailer TE Transfer-Encoding Upgrade
        flags = f->skip | (f->hopbyhop << 1);
        if (flags) {
            lua_pushinteger(L, flags);
            lua_setfield(L, 4, name);
        }
    }
    lua_settop(L, 4);
    lua_pushinteger(L, max_fields);
    lua_replace(L, 2);
    return 3;

    // #define F_FIELD_INDEX(NAME) \
    //     if (NXT_UNIT_NONE_FIELD != req->NAME##_field) { \
    //         nxt_unit_field_t *f = req->fields + req->NAME##_field; \
    //         lua_pushlstring(L, (const char *)nxt_unit_sptr_get(&f->name), f->name_length); \
    //         lua_setfield(L, -2, #NAME); \
    //     }
    // lua_newtable(L);
    // F_FIELD_INDEX(content_length);
    // F_FIELD_INDEX(content_type);
    // F_FIELD_INDEX(cookie);
    // F_FIELD_INDEX(authorization);
    // lua_setfield(L, -2, "field_refs");
}


void request_handler(nxt_unit_request_info_t *req) {
    int rc;
    nxt_unit_request_t *r = req->request;
    lua_State *L = req->unit->data;
    // context_t *uctx;
    request_t *ureq;

    uint16_t status;

    const char *content;
    size_t content_length;

    const char *name, *value;
    size_t name_len, value_len;
    uint32_t max_fields_count, max_fields_size;

    lua_rawgeti(L, LUA_REGISTRYINDEX, PTR2REF(req->ctx->data)); // uctx
    // GET_CTX(uctx, -1);
    lua_getiuservalue(L, -1, 1); // function: request_handler
    lua_newtable(L); // arg-1: req
    #define F_STR(NAME) \
        lua_pushlstring(L, (const char *)nxt_unit_sptr_get(&r->NAME), r->NAME##_length); \
        lua_setfield(L, -2, #NAME)
    #define F_STR0(NAME) \
        lua_pushstring(L, (const char *)nxt_unit_sptr_get(&r->NAME)); \
        lua_setfield(L, -2, #NAME)
    #define F_INT(NAME) \
        lua_pushinteger(L, r->NAME); \
        lua_setfield(L, -2, #NAME)
    #define F_BOOL(NAME) \
        lua_pushboolean(L, r->NAME); \
        lua_setfield(L, -2, #NAME)

    F_STR(method);
    F_STR(version);
    F_STR(remote);
    F_STR(local);
    F_STR(server_name);
    F_STR(target);
    F_STR(path);
    F_STR(query);

    // NOTE hsq 经过测试，其与 preread_content 长度匹配，
    //      直至超过 8M Unit 反馈 413 Payload Too Large
    F_INT(content_length);
    // F_STR0(preread_content);
    lua_pushlstring(L, (const char *)nxt_unit_sptr_get(&r->preread_content),
                        r->content_length);
    lua_setfield(L, -2, "preread_content");

    F_INT(tls);
    F_INT(websocket_handshake);
    F_INT(app_target);

    F_INT(fields_count);

    ureq = lua_newuserdatauv(L, sizeof(request_t), 0);
    ureq->req = r;
    luaL_setmetatable(L, MT_REQUEST);
    lua_setfield(L, -2, "request");

    lua_call(L, 1, 3);

    status  = lua_tointeger(L, -3);
    content = lua_tolstring(L, -2, &content_length);

    max_fields_count = lua_rawlen(L, -1) / 2;
    // max_fields_size = lua_rawlen(L, -2);
    max_fields_size = content_length;
    for (uint32_t i = 0; i < max_fields_count; i++) {
        lua_rawgeti(L, -1, i * 2 + 1);
        max_fields_size += lua_rawlen(L, -1);
        lua_rawgeti(L, -2, i * 2 + 2);
        max_fields_size += lua_rawlen(L, -1);
        lua_pop(L, 2);
    }
    max_fields_size += max_fields_count * 4;

    rc = nxt_unit_response_init(req, status, max_fields_count, max_fields_size);
    if (NXT_UNIT_OK != rc) {
        nxt_unit_alert(NULL, "%s 失败！", "response_init");
        nxt_unit_request_done(req, NXT_UNIT_ERROR);
    }

    for (uint32_t i = 0; i < max_fields_count; i++) {
        lua_rawgeti(L, -1, i * 2 + 1);
        lua_rawgeti(L, -2, i * 2 + 2);
        name = lua_tolstring(L, -2, &name_len);
        value = lua_tolstring(L, -1, &value_len);
        rc = nxt_unit_response_add_field(req, name, name_len, value, value_len);
        if (NXT_UNIT_OK != rc) {
            nxt_unit_alert(NULL, "%s 失败(%*s: %*s)！", "add_field",
                    (int)name_len, name, (int)value_len, value);
            lua_pop(L, 2);
            nxt_unit_request_done(req, NXT_UNIT_ERROR);
            break;
        }
        lua_pop(L, 2);
    }

    rc = nxt_unit_response_add_content(req, content, content_length);
    if (NXT_UNIT_OK != rc) {
        nxt_unit_alert(NULL, "%s 失败！", "add_content");
        nxt_unit_request_done(req, NXT_UNIT_ERROR);
    }

    rc = nxt_unit_response_send(req);
    if (NXT_UNIT_OK != rc) {
        nxt_unit_alert(NULL, "%s 失败！", "response_send");
        nxt_unit_request_done(req, NXT_UNIT_ERROR);
    }

    nxt_unit_request_done(req, NXT_UNIT_OK);
}

static const luaL_Reg lib_funcs[] = {
    {"init",     lib_func_init},
    {"log",      lib_func_log},
    {"getpid",   lib_func_getpid},
    {"getppid",  lib_func_getppid},
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

/*
** metamethods for context
*/
static const luaL_Reg ctx_meta_mtds[] = {
    {"__index",    NULL}, /* place holder */
    {"__gc",       ctx_mtd_done},
    {NULL,         NULL}};

static const luaL_Reg req_mtds[] = {
    {"fields", req_mtd_fields},
    {NULL,     NULL}
};

/*
** metamethods for request
*/
static const luaL_Reg req_meta_mtds[] = {
    {"__index",    NULL}, /* place holder */
    {NULL,         NULL}};

// NOTE hsq 用函数封装则传入的 luaL_Reg[] 变成指针后无法取得项目数。
#define new_meta(mt_name, mt, mtds) { \
    rc = luaL_newmetatable(L, mt_name); \
    if (!rc) { \
        nxt_unit_alert(NULL, "注册元表 %s 失败！已经注册。", mt_name); \
    } \
    luaL_setfuncs(L, mt, 0); \
    luaL_newlib(L, mtds); \
    lua_setfield(L, -2, "__index"); \
    lua_pop(L, 1); \
}


LUAMOD_API int luaopen_unit_core(lua_State *L) {
    int rc;

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

    // 注册 userdadta: context_t
    new_meta(MT_CONTEXT, ctx_meta_mtds, ctx_mtds);
    new_meta(MT_REQUEST, req_meta_mtds, req_mtds);

    // 在注册表中缓存 string.format
    // int top = lua_absindex(L, -1);
    // luaL_openlibs(L);
    #if 0
    assert(lua_getglobal(L, "string") == LUA_TTABLE);
    assert(lua_getfield(L, -1, "format") == LUA_TFUNCTION);
    LUA_RIDX_STR_FORMAT = luaL_ref(L, LUA_REGISTRYINDEX);
    lua_pop(L, 1);
    #else
    assert(luaL_dostring(L, "return string.format") == 0);
    // assert(ua_isfunction(L, -1));
    LUA_RIDX_STR_FORMAT = luaL_ref(L, LUA_REGISTRYINDEX);
    #endif

    if (LUA_NOREF == LUA_RIDX_STR_FORMAT) {
        #define ERR_NEED_STR_FORMAT "log() 需要 string.format(fmt, ...) ！"
        nxt_unit_log(NULL, NXT_UNIT_LOG_ALERT, ERR_NEED_STR_FORMAT);
        luaL_error(L, ERR_NEED_STR_FORMAT);
    }
    // lua_settop(L, top);

    return 1;
}
