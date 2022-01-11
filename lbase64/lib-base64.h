#include <luaconf.h>
#include <lua.h>

LUAMOD_API int luaopen_lbase64(lua_State *);

LUAMOD_API int lib_func_set_codec(lua_State *);
LUAMOD_API int lib_func_encode(lua_State *);
LUAMOD_API int lib_func_decode(lua_State *);

LUAMOD_API int lib_func_stream_encode_init(lua_State *);
LUAMOD_API int lib_func_stream_encode(lua_State *);
LUAMOD_API int lib_func_stream_encode_final(lua_State *);
LUAMOD_API int lib_func_stream_decode_init(lua_State *);
LUAMOD_API int lib_func_stream_decode(lua_State *);
