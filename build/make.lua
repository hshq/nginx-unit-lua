
package.path =  table.concat({
    -- '../lib/'..ver..'/?.lua',
    -- TODO hsq 自动配置路径，如系统路径、完整路径、自动搜索等。
    '../../lib/?.lua',
    package.path,
}, ';')

local base = require 'utils_base'

local _M

local join     = base.join
local push     = base.push
local readonly = base.readonly
local is_jit   = base.is_jit
local sh       = base.sh
local unpack   = table.unpack


local function cmd(array)
    return join(array, ' ')
end

local function I(dir)
    return '-I' .. dir
end

local function L(dir)
    return '-L' .. dir
end

local function lib(name)
    return '-l' .. name
end


local function gen(config)
    local config = _M.env(config)

    -- TODO hsq 必须在库目录中执行。
    local inc_file = '../make.inc.lua'
    if is_jit() then
        _G._ENV = config
        config = assert(loadfile(inc_file))()
    else
        config = assert(loadfile(inc_file, 'bt', config))()
    end

    local mk = {}

    for _, var in pairs(config.vars) do
        push(mk, cmd{var[1], '=', var[2] .. '\n'})
    end

    for _, rule in ipairs(config.rules) do
        local t, ds, as = rule.target, rule.deps, rule.actions
        if ds then
            push(mk, cmd{t, ':', cmd(ds)})
        else
            push(mk, cmd{t, ':'})
        end
        if as then
            for _, a in ipairs(as) do
                push(mk, '\t' .. a)
            end
        end
        push(mk, '')
    end

    local f = assert(io.open(_M.MK_FILE, 'w'))
    f:write(join(mk, '\n'))
    assert(f:close())

    print('生成 ' .. _M.MK_FILE .. ' OK')
    return true
end

local function env(tbl)
    return setmetatable(tbl, {
        __index = function(t, k)
            return _M[k] or _G[k]
        end,
        __call = function(t, fields)
            local fs = {}
            for f in fields:gmatch('[%w_]+') do
                local v = t[f]
                if not v then
                    error('invalid variable: ' .. f, 2)
                end
                push(fs, v)
            end
            return unpack(fs)
        end,
    })
end

_M = {
    CC       = 'gcc',
    MAKE     = 'make', -- '$(MAKE)'
    INC_DIRS = readonly({}),
    LD_DIRS  = readonly({}),
    DBG_OPTS = '',
    CFLAGS   = '',
    LDFLAGS  = '',
    LIBS     = readonly({}),
    MK_FILE  = './Makefile',

    cmd  = cmd,
    sh   = sh,
    I    = I,
    L    = L,
    lib  = lib,

    gen  = gen,
    env  = env,
}

return _M