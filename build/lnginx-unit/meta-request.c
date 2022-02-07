#include "lib-nginx-unit.h"


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
        const char *name = GET_STR(&f->name);
        const char *value = GET_STR(&f->value);
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
        // NOTE hsq fields_hopbyhop 只有 8 个：
        //      Connection Keep-Alive Proxy-Authenticate Proxy-Authorization
        //      Trailer TE Transfer-Encoding Upgrade
        //      Content-Length 也被 Nginx 处理，比如发送 chunked 编码，见 resty/http 模块。
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
    //         lua_pushlstring(L, GET_STR(&f->name), f->name_length); \
    //         lua_setfield(L, -2, #NAME); \
    //     }
    // lua_newtable(L);
    // F_FIELD_INDEX(content_length);
    // F_FIELD_INDEX(content_type);
    // F_FIELD_INDEX(cookie);
    // F_FIELD_INDEX(authorization);
    // lua_setfield(L, -2, "field_refs");
}


static const luaL_Reg req_mtds[] = {
    {"fields", req_mtd_fields},
    {NULL,     NULL}
};

//  metamethods for request
static const luaL_Reg req_meta_mtds[] = {
    {"__index",    NULL}, /* place holder */
    {NULL,         NULL}};


LUAMOD_API void reg_req(lua_State *L) {
    new_meta(MT_REQUEST, req_meta_mtds, req_mtds);
}
