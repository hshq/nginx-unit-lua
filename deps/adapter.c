#include <lua.h>

#if LUA_VERSION_NUM == 501

#include "adapter.h"

LUA_API void *lua_newuserdatauv(lua_State *L, size_t sz, int nuvalue) {
    void *ud = lua_newuserdata(L, sz);
    if (nuvalue > 0) {
        lua_createtable(L, nuvalue, 0);
        lua_setfenv(L, -2);
    }
    return ud;
}

LUA_API int lua_getiuservalue(lua_State *L, int idx, int n) {
    lua_getfenv(L, idx);
    lua_rawgeti(L, -1, n);
    lua_replace(L, -2);
    return lua_type(L, -1);
}

LUA_API int lua_setiuservalue(lua_State *L, int idx, int n) {
    lua_getfenv(L, idx);
    lua_insert(L, -2);
    lua_rawseti(L, -2, n);
    lua_pop(L, 1);
    return 1;
}

#endif
