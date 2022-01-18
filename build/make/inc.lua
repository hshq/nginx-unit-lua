-- NOTE hsq 参考 lpeg 库

-- NOTE hsq 只是为了避免语言服务器警告
-- TODO hsq 推广这种导入方法？ use(mod, '...') use'...' of 'mod'
-- local join, push, map, merge, cmd = _ENV('join, push, map, merge, cmd')
local I, L, lib, sh, cmd          = _ENV('I, L, lib, sh, cmd')
local INC_DIRS, LD_DIRS, LIBS     = _ENV('INC_DIRS, LD_DIRS, LIBS')
local CFLAGS, LDFLAGS, DBG_OPTS   = _ENV('CFLAGS, LDFLAGS, DBG_OPTS')
local DEP_OBJS, O_FILES           = _ENV('DEP_OBJS, O_FILES')
local LIB_NAME, MK_FILE, CC, MAKE = _ENV('LIB_NAME, MK_FILE, CC, MAKE')
-- TODO hsq 搜索 is_jit jit 和 _ENV
-- local is_jit = _ENV('is_jit')

package.path = table.concat({
    -- '../lib/'..ver..'/?.lua',
    '../lib/?.lua',
    package.path,
}, ';')

local base = require 'utils.base'
local join = base.join
local push = base.push
local map  = base.map
local merge = base.merge
local is_jit = base.is_jit

local DEBUG = true
local COPTS = {
    DEBUG   = cmd{'-g', DBG_OPTS},
    RELEASE = '-O2',
}
local LUA_VER = _VERSION:match('^Lua (.+)$')
local LIB_EXT = 'so'

local LUA_INC, LUA_LIB
if LUA_VER == '5.4' then
    -- /usr/local/lib/pkgconfig/lua$(LUA_VER).pc
    LUA_INC = '/usr/local/include/lua' .. LUA_VER
    -- LUA_LIB = 'lua' .. LUA_VER
elseif is_jit() then
    local JIT_DIR = '/usr/local/opt/luajit-openresty'
    -- lib/pkgconfig/luajit.pc
    LUA_INC = JIT_DIR .. '/include/luajit-2.1'
    -- NOTE hsq 产生奇怪问题：遍历 core.so 正常，直接取字段就是 nil 。
    -- LUA_LIB = 'luajit'
    -- LD_DIRS = merge({JIT_DIR .. '/lib'}, LD_DIRS)
else
    error('Lua 5.4 or LuaJIT required')
end

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

local LIB_FILE = ('../../lib/%s/%s.%s'):format(LUA_VER, LIB_NAME, LIB_EXT)

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
        deps = {'../make/lib.lua', '../make/inc.lua', '../make.lua'},
    },{
        target = 'clean',
        actions = {
            cmd{'rm -f', MK_FILE, cmd(O_FILES), '*.'..LIB_EXT},
            -- cmd{'rm -f', MK_FILE, '*.o *.'..LIB_EXT},
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