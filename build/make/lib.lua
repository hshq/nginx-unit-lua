local base = require 'utils.base'

local _M

local join, push, readonly, is_jit, sh, write_file =
    base 'join, push, readonly, is_jit, sh, write_file'
local unpack = table.unpack


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


local function gen(target, inc_file, debug)
    local mk_file = target .. '/' .. _M.MK_FILE
    local config = _M.env(require(target .. '.make'))
    config.DEBUG = debug

    if is_jit then
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

    write_file(mk_file, join(mk, '\n'))

    print('生成 ' .. mk_file .. ' OK')
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
                if v == nil then
                    error('invalid variable: ' .. f, 2)
                end
                push(fs, v)
            end
            return unpack(fs)
        end,
    })
end

_M = exportable {
    CC       = 'gcc',
    MAKE     = 'make', -- '$(MAKE)'
    INC_DIRS = readonly({}),
    LD_DIRS  = readonly({}),
    DBG_OPTS = '',
    CFLAGS   = '',
    LDFLAGS  = '',
    LIBS     = readonly({}),
    MK_FILE  = 'Makefile',

    cmd  = cmd,
    sh   = sh,
    I    = I,
    L    = L,
    lib  = lib,

    gen  = gen,
    env  = env,
}

return _M