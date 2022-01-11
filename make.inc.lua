-- NOTE hsq 参考 lpeg 库

-- NOTE hsq 只是为了避免语言服务器警告
local join, push, map, merge, cmd = _ENV('join, push, map, merge, cmd')
local I, L, lib, sh               = _ENV('I, L, lib, sh')
local INC_DIRS, LD_DIRS, LIBS     = _ENV('INC_DIRS, LD_DIRS, LIBS')
local CFLAGS, LDFLAGS, DBG_OPTS   = _ENV('CFLAGS, LDFLAGS, DBG_OPTS')
local DEP_OBJS, O_FILES           = _ENV('DEP_OBJS, O_FILES')
local LIB_NAME, MK_FILE, CC, MAKE = _ENV('LIB_NAME, MK_FILE, CC, MAKE')

local DEBUG = true
local COPTS = {
    DEBUG   = cmd{'-g', DBG_OPTS},
    RELEASE = '-O2',
}
local LUA_VER = '5.4'
local LIB_EXT = 'so'

-- /usr/local/lib/pkgconfig/lua$(LUA_VER).pc
local LUA_INC = '/usr/local/include/lua' .. LUA_VER
local LUA_LIB = 'lua' .. LUA_VER

local LINE_SEP = ' \\\n\t'

local INC_DIRS = join(map(merge({LUA_INC}, INC_DIRS), I), LINE_SEP)
local LIBS     = cmd(map(merge({LUA_LIB}, LIBS), lib)) .. LINE_SEP ..
                    join(map(LD_DIRS, L), LINE_SEP)

local C_WARNS = join({
    '-Wall -Wextra -pedantic',
    '-Waggregate-return',
    '-Wcast-align',
    '-Wcast-qual',
    '-Wdisabled-optimization',
    '-Wpointer-arith',
    '-Wshadow',
    '-Wsign-compare',
    '-Wundef',
    '-Wwrite-strings',
    '-Wbad-function-cast',
    '-Wdeclaration-after-statement',
    '-Wmissing-prototypes',
    '-Wnested-externs',
    '-Wstrict-prototypes',
    '-Wunreachable-code',
    '-Wno-variadic-macros',
    '-Wno-gnu-zero-variadic-macro-arguments',
}, LINE_SEP)

COPTS = DEBUG and COPTS.DEBUG or COPTS.RELEASE
local OS = sh('uname -s'):match('[^%s]+') -- Darwin/Linux

local OS_LDFLAGS = {
    Linux = '-shared -fPIC',
    Darwin = '-bundle -undefined dynamic_lookup',
}

local CFLAGS  = cmd{CFLAGS, '$(INC_DIRS)', '$(C_WARNS)', '$(COPTS)', '-std=c99 -fPIC'}
-- local LIBS    = cmd{LIBS, LUA_LIB}
local LDFLAGS = cmd{LDFLAGS, OS_LDFLAGS[OS]}

local LIB_FILE = ('../lib/%s/%s.%s'):format(LUA_VER, LIB_NAME, LIB_EXT)

local vars = {
    {'LUA_VER',  LUA_VER},
    {'LIB_EXT',  LIB_EXT},
    {'COPTS',    COPTS},
    {'INC_DIRS', INC_DIRS},
    {'C_WARNS',  C_WARNS},
    {'CFLAGS',   CFLAGS},
    {'LIBS',     LIBS},
    {'LDFLAGS',  LDFLAGS},
}

local rules = {{
        target = 'all',
        actions = {
            cmd{MAKE, LIB_FILE},
        },
    },{
        target = LIB_FILE,
        deps = merge(DEP_OBJS, O_FILES),
        actions = {
            cmd{'env', CC, '$(LIBS)', '$(LDFLAGS)', '-o $@ $^'},
        },
    },{
        target = cmd(O_FILES), -- '$(O_FILES)'
        deps = {'make.lua', '../make.inc.lua', '../make.lua'},
    },{
        target = 'clean',
        actions = {
            -- cmd{'rm -f', MK_FILE, cmd(O_FILES), '*.'..LIB_EXT},
            cmd{'rm -f', MK_FILE, '*.o *.'..LIB_EXT},
        },
    },
}

for _, of in ipairs(O_FILES) do
    push(rules, {
        target = of,
        deps = {(of:gsub('%.o$', '.h'))},
    })
end

return {vars = vars, rules = rules}