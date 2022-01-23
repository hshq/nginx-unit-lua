#include "lib-nginx-unit.h"

#include <stdlib.h>


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
        lua_pushlstring(L, GET_STR(&r->NAME), r->NAME##_length); \
        lua_setfield(L, -2, #NAME)
    #define F_STR0(NAME) \
        lua_pushstring(L, GET_STR(&r->NAME)); \
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
    lua_pushlstring(L, GET_STR(&r->preread_content),
                        r->content_length);
    lua_setfield(L, -2, "preread_content");

    F_INT(tls);
    F_INT(websocket_handshake);
    // TODO hsq 同一个 App 的多个进程的编号？似乎不是不同的 App 的编号。
    F_INT(app_target);

    F_INT(fields_count);

    for (uint32_t i = 0; i < r->fields_count; i++) {
        nxt_unit_field_t *f = &r->fields[i];
        if (f->hash == NXT_UNIT_HASH_HOST) {
            // const char *port = strrchr(GET_STR(&f->value), ':');
            // lua_pushinteger(L, port ? atoi(port + 1) : 80);
            const char *port = GET_STR(&f->value) + r->server_name_length;
            lua_pushinteger(L, *port ==':' ? atoi(port + 1) : 80);
            lua_setfield(L, -2, "server_port");
        }
    }

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
