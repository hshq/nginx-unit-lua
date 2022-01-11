
#define lib_base64_c
#define LUA_LIB

#include <lua.h>
#include <lauxlib.h>

#include "config.h"
#include "libbase64.h"
#include "lib-base64.h"


#define AUTO_CODEC 0
#define ERR_CODEC  "Unsupported codec"

static int use_codec = AUTO_CODEC;


// NOTE msg 是字符串字面量
#define CHECK(err_cond, msg) if (err_cond) { \
        lua_pushnil(L); \
        lua_pushliteral(L, msg); \
        return 2; \
    }


struct kv {
    const char *key;
    int val;
};

#define KV_COUNT(VEC) (sizeof(VEC) / sizeof(struct kv))

// static struct kv have[] = {
//     {"avx2",   HAVE_AVX2},
//     {"neon32", HAVE_NEON32},
//     {"neon64", HAVE_NEON64},
//     {"ssse3",  HAVE_SSSE3},
//     {"sse41",  HAVE_SSE41},
//     {"sse42",  HAVE_SSE42},
//     {"avx",    HAVE_AVX},
// };
static struct kv codec[] = {
    {"auto",    AUTO_CODEC},
    #if HAVE_AVX2
    {"avx2",    BASE64_FORCE_AVX2},
    #endif
    #if HAVE_NEON32
    {"neon32",  BASE64_FORCE_NEON32},
    #endif
    #if HAVE_NEON64
    {"neon64",  BASE64_FORCE_NEON64},
    #endif
    {"plain",   BASE64_FORCE_PLAIN},
    #if HAVE_SSSE3
    {"ssse3",   BASE64_FORCE_SSSE3},
    #endif
    #if HAVE_SSE41
    {"sse41",   BASE64_FORCE_SSE41},
    #endif
    #if HAVE_SSE42
    {"sse42",   BASE64_FORCE_SSE42},
    #endif
    #if HAVE_AVX
    {"avx",     BASE64_FORCE_AVX},
    #endif
};


static int check_codec(int c) {
    for (size_t i = 0; i < KV_COUNT(codec); i++) {
        if (c == codec[i].val) {
            return c;
        }
    }
    return -1;
}


// @codec int
// return old codec|nil, msg
LUAMOD_API int lib_func_set_codec(lua_State *L) {
    int c = luaL_optinteger(L, 1, AUTO_CODEC);
    CHECK(-1 == check_codec(c), ERR_CODEC);

    lua_pushinteger(L, use_codec);
    use_codec = c;
    return 1;
}

// @str string
// @no_padding? boolean
LUAMOD_API int lib_func_encode(lua_State *L) {
    const char *src;
    char *dst;
    size_t slen, dlen;
    int no_padding;
    lua_Alloc alloc;
    void *alloc_ud;

    src = luaL_checklstring(L, 1, &slen);
    no_padding = lua_toboolean(L, 2);

    dlen = slen * 4 / 3 + 8;
    alloc = lua_getallocf(L, &alloc_ud);
    dst = alloc(alloc_ud, NULL, 0, dlen);
    if (!dst) {
        return luaL_error(L, "分配存储失败！");
    }

    base64_encode(src, slen, dst, &dlen, use_codec);
    if (no_padding) {
        while (dst[dlen-1] == '=') dlen--;
    }

    lua_pushlstring(L, dst, dlen);
    alloc(alloc_ud, dst, dlen, 0);
    return 1;
}

// @str string
// return string|nil, msg
LUAMOD_API int lib_func_decode(lua_State *L) {
    const char *src;
    char *dst;
    size_t slen, dlen;
    lua_Alloc alloc;
    void *alloc_ud;
    int ret;

    src = luaL_checklstring(L, 1, &slen);

    dlen = slen * 3 / 4 + 8;
    alloc = lua_getallocf(L, &alloc_ud);
    dst = alloc(alloc_ud, NULL, 0, dlen);
    if (!dst) {
        return luaL_error(L, "分配存储失败！");
    }

    ret = base64_decode(src, slen, dst, &dlen, use_codec);
    CHECK(0 == ret, "invalid input");
    CHECK(-1 == ret, ERR_CODEC);

    lua_pushlstring(L, dst, dlen);
    alloc(alloc_ud, dst, dlen, 0);
    return 1;
}

LUAMOD_API int lib_func_stream_encode_init(lua_State *L) {
    return luaL_error(L, "TODO base64_stream_encode_init");
}

LUAMOD_API int lib_func_stream_encode(lua_State *L) {
    return luaL_error(L, "TODO base64_stream_encode");
}

LUAMOD_API int lib_func_stream_encode_final(lua_State *L) {
    return luaL_error(L, "TODO base64_stream_encode_final");
}

LUAMOD_API int lib_func_stream_decode_init(lua_State *L) {
    return luaL_error(L, "TODO base64_stream_decode_init");
}

LUAMOD_API int lib_func_stream_decode(lua_State *L) {
    return luaL_error(L, "TODO base64_stream_decode");
}

static const luaL_Reg lib_funcs[] = {
    {"set_codec",           lib_func_set_codec},
    {"encode",              lib_func_encode},
    {"decode",              lib_func_decode},
    {"stream_encode_init",  lib_func_stream_encode_init},
    {"stream_encode",       lib_func_stream_encode},
    {"stream_encode_final", lib_func_stream_encode_final},
    {"stream_decode_init",  lib_func_stream_decode_init},
    {"stream_decode",       lib_func_stream_decode},
    /* placeholders */
    // {"have",  NULL},
    {"codec", NULL},
    {NULL,    NULL}
};

#define REG_KV(VEC, TYPE) { \
    size_t CNT = KV_COUNT(VEC); \
    lua_createtable(L, 0, CNT); \
    for (size_t i = 0; i < CNT; i++) { \
        lua_push##TYPE(L, VEC[i].val); \
        lua_setfield(L, -2, VEC[i].key); \
    } \
    lua_setfield(L, -2, #VEC); \
}

LUAMOD_API int luaopen_lbase64(lua_State *L) {
    luaL_newlib(L, lib_funcs);

    // REG_KV(have, boolean);
    REG_KV(codec, integer);

    return 1;
}
