local _M

local join = table.concat
local push = table.insert

local unpack = table.unpack or _G.unpack

-- TODO hsq 重复定义。
local function map(tbl, func)
    for k, v in pairs(tbl) do
        tbl[k] = func(v)
    end
    return tbl
end

local function merge(dst, src)
    for i, v in ipairs(src) do
        push(dst, v)
    end
    local k, v = #src
    k = k ~= 0 and k or nil
    k, v = next(src, k)
    while(k) do
        dst[k] = v
        k, v = next(src, k)
    end
    return dst
end

local function readonly(tbl)
    return setmetatable(tbl, {
        __newindex = function(t, k, v)
            error('readonly', 2)
        end,
    })
end


local function cmd(array)
    return table.concat(array, ' ')
end

local function sh(cmd)
    local f = assert(io.popen(cmd, 'r'))
    local r = assert(f:read('*a'))
    f:close()
    return r
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


local function is_jit()
    return (_VERSION == 'Lua 5.1' and _G.jit) and true or false
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

    join     = join,
    push     = push,
    map      = map,
    merge    = merge,
    readonly = readonly,
    is_jit   = is_jit,

    cmd  = cmd,
    sh   = sh,
    I    = I,
    L    = L,
    lib  = lib,

    gen  = gen,
    env  = env,
}

return _M