#ifndef ADAPTER_H
#define ADAPTER_H

#include <lua.h>

#if LUA_VERSION_NUM == 501

#define LUAMOD_API LUA_API
#define lua_rawlen lua_objlen

// NOTE hsq 影响基于 lua_getfield 定义的宏
#define lua_getfield(L, idx, k) \
    (lua_getfield((L), (idx), (k)), lua_type(L, -1))

LUA_API void *(lua_newuserdatauv) (lua_State *L, size_t sz, int nuvalue);
LUA_API int  (lua_getiuservalue) (lua_State *L, int idx, int n);
LUA_API int   (lua_setiuservalue) (lua_State *L, int idx, int n);

#endif

#endif // ADAPTER_H
