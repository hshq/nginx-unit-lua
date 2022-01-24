#define lib_codec_c
#define LUA_LIB

#include <lua.h>
#include <lauxlib.h>

#include <base64/lib/config.h>
#include <base64/include/libbase64.h>

#include "lib-codec.h"

#include <openssl/md5.h>
#include <gityf_crc/crc32.h>

#include <time.h>
#include <sys/time.h>


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
static struct kv base64_codec[] = {
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
    for (size_t i = 0; i < KV_COUNT(base64_codec); i++) {
        if (c == base64_codec[i].val) {
            return c;
        }
    }
    return -1;
}


// @codec int
// return old codec|nil, msg
LUAMOD_API int lib_func_base64_set_codec(lua_State *L) {
    int c = luaL_optinteger(L, 1, AUTO_CODEC);
    CHECK(-1 == check_codec(c), ERR_CODEC);

    lua_pushinteger(L, use_codec);
    use_codec = c;
    return 1;
}

// @str string
// @no_padding? boolean
LUAMOD_API int lib_func_base64_encode(lua_State *L) {
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
LUAMOD_API int lib_func_base64_decode(lua_State *L) {
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

// LUAMOD_API int lib_func_base64_stream_encode_init(lua_State *L) {
//     return luaL_error(L, "TODO base64_stream_encode_init");
// }

// LUAMOD_API int lib_func_base64_stream_encode(lua_State *L) {
//     return luaL_error(L, "TODO base64_stream_encode");
// }

// LUAMOD_API int lib_func_base64_stream_encode_final(lua_State *L) {
//     return luaL_error(L, "TODO base64_stream_encode_final");
// }

// LUAMOD_API int lib_func_base64_stream_decode_init(lua_State *L) {
//     return luaL_error(L, "TODO base64_stream_decode_init");
// }

// LUAMOD_API int lib_func_base64_stream_decode(lua_State *L) {
//     return luaL_error(L, "TODO base64_stream_decode");
// }

LUAMOD_API int lib_func_md5(lua_State *L) {
    const char *str;
    size_t len;
    boolean_t bin;

    // unsigned char md[MD5_DIGEST_LENGTH];
    unsigned char *md;
    char         buf[MD5_DIGEST_LENGTH * 2];

    str = luaL_checklstring(L, 1, &len);
    bin = lua_toboolean(L, 2);

    // MD5((const unsigned char *)str, len, md);
    md = MD5((const unsigned char *)str, len, NULL);

    if (bin) {
        lua_pushlstring(L, (const char *)md, MD5_DIGEST_LENGTH);
    } else {
        for (int i = 0; i < MD5_DIGEST_LENGTH; i++) {
            sprintf(buf + i * 2, "%02x", md[i]);
        }
        lua_pushlstring(L, buf, MD5_DIGEST_LENGTH * 2);
    }

    return 1;
}

LUAMOD_API int lib_func_crc32(lua_State *L) {
    const char *str;
    size_t len;

    str = luaL_checklstring(L, 1, &len);
    lua_pushinteger(L, crc32(str, len));

    return 1;
}

// TODO hsq FFI 实现更好：标准库的简单封装？
LUAMOD_API int lib_func_parse_time(lua_State *L) {
    const char *time;
    const char *fmt;
    struct tm tm;
    time_t sec;

    time = luaL_checkstring(L, 1);
    fmt = luaL_checkstring(L, 2);
    if (strptime(time, fmt, &tm)) {
        sec = timegm(&tm);
        lua_pushinteger(L, sec);
    } else {
        lua_pushnil(L);
    }

    return 1;
}

LUAMOD_API int lib_func_now(lua_State *L) {
    struct timeval tp;
    struct timezone tzp;
    boolean_t all;
    int rc;

    all = lua_toboolean(L, 1);
    rc = gettimeofday(&tp, all ? &tzp : NULL);
    if (rc) return 0;
    if (all) {
        lua_pushinteger(L, tp.tv_sec);
        lua_pushinteger(L, tp.tv_usec);
        lua_pushinteger(L, tzp.tz_minuteswest);
        lua_pushboolean(L, tzp.tz_dsttime);
        return 4;
    } else {
        lua_pushnumber(L, tp.tv_sec + tp.tv_usec / 1000000.0);
        return 1;
    }
}

static const luaL_Reg lib_funcs[] = {
    {"set_base64_codec",    lib_func_base64_set_codec},
    {"encode_base64",       lib_func_base64_encode},
    {"decode_base64",       lib_func_base64_decode},
    {"base64_encode",       lib_func_base64_encode},
    {"base64_decode",       lib_func_base64_decode},

    // {"stream_encode_init",  lib_func_base64_stream_encode_init},
    // {"stream_encode",       lib_func_base64_stream_encode},
    // {"stream_encode_final", lib_func_base64_stream_encode_final},
    // {"stream_decode_init",  lib_func_base64_stream_decode_init},
    // {"stream_decode",       lib_func_base64_stream_decode},

    {"md5",                 lib_func_md5},
    {"crc32",               lib_func_crc32},
    {"parse_time",          lib_func_parse_time},
    {"now",                 lib_func_now},
    /* placeholders */
    // {"have",  NULL},
    {"base64_codec", NULL},
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

LUAMOD_API int luaopen_lcodec(lua_State *L) {
    luaL_newlib(L, lib_funcs);

    // REG_KV(have, boolean);
    REG_KV(base64_codec, integer);

    return 1;
}
