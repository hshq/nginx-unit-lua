return {
    LIB_NAME = 'lnginx-unit/core',
    DEP_OBJS = {'/usr/local/lib/libunit.a'},
    O_FILES  = {'lib-nginx-unit.o',
                'callbacks.o',
                'meta-context.o',
                'meta-request.o',
                '../deps/adapter.o'},
    INC_DIRS = {'../deps',},
    -- NOTE hsq lor 框架依赖 resty.aes 。
    LIBS     = {'ssl',
                'crypto'},
    LD_DIRS  = {'/usr/local/opt/openssl/lib'},
    -- NOTE hsq NXT_DEBUG 只影响 nxt_unit_debug ，但 Lua 模块只用了 nxt_unit_log
    DBG_OPTS = '-DNXT_DEBUG=1',
}