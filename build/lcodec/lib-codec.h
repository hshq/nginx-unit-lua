#ifndef LIB_CODEC_H
#define LIB_CODEC_H

#include <luaconf.h>
#include <lua.h>

#include <adapter.h>

LUAMOD_API int luaopen_lcodec(lua_State *);

LUAMOD_API int lib_func_base64_set_codec(lua_State *);
LUAMOD_API int lib_func_base64_encode(lua_State *);
LUAMOD_API int lib_func_base64_decode(lua_State *);

LUAMOD_API int lib_func_md5(lua_State *);
LUAMOD_API int lib_func_crc32(lua_State *);

#endif // LIB_CODEC_H
