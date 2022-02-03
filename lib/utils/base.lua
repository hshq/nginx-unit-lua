-- XXX 放在系统路径中
-- XXX 加载后，在字符串元表中注册了一些方法

local api   = require 'utils.adapter'

local type         = type
local next         = next
local pairs        = pairs
local ipairs       = ipairs
local error        = error
local assert       = assert
local require      = require
local loaded       = package.loaded
local getmetatable = getmetatable
local setmetatable = setmetatable
local push         = table.insert
local pop          = table.remove
local join         = table.concat
local unpack       = table.unpack
local io_popen     = io.popen
local io_open      = io.open
local _G           = _G


local _ENV = {}


local function write_file(file, content)
    local f = assert(io_open(file, 'w'))
    f:write(content)
    assert(f:close())
end

local function sh(cmd)
    local f = assert(io_popen(cmd, 'r'))
    local r = assert(f:read('*a'))
    f:close()
    return r
end


local function clear(tbl)
    for k in pairs(tbl) do
        tbl[k] = nil
    end
end

local function keys(tbl)
    local ks, i = {}, 1
    for k in pairs(tbl) do
        ks[i] = k
        i = i + 1
    end
    return ks
end

local function map(tbl, func)
    for k, v in pairs(tbl) do
        tbl[k] = func(v)
    end
    return tbl
end

-- @depth? int|nil 缺省为完整深度拷贝
local function clone(tbl, depth)
    local tbl2 = {}
    for k, v in pairs(tbl) do
        if (not depth or depth > 0) and type(v) == 'table' then
            tbl2[k] = clone(v, depth and depth - 1)
        else
            tbl2[k] = v
        end
    end
    return tbl2
end

-- 数组部分追加，散列部分覆盖。
local function merge(dst, src)
    -- for k, v in pairs(src) do
    --     dst[k] = v
    -- end
    -- return dst
    for i, v in ipairs(src) do
        push(dst, v)
    end
    local k, v = #src, nil
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


-- @plain boolean @delimiter 是不是模式
local function split(str, delimiter, limit, plain)
    local vec = {}
    if type(str) ~= 'string' or str == '' then
        return vec
    end
    local len = 0
    local posx = 1
    local posy = str:find(delimiter, posx, plain)
    while posy do
        if limit and len == limit then
            return vec
        end
        len = len + 1
        vec[len] = str:sub(posx, posy - 1)
        posx = posy + 1
        posy = str:find(delimiter, posx, plain)
    end
    if limit and len == limit then
        return vec
    end
    len = len + 1
    vec[len] = str:sub(posx)
    return vec
end


-- XXX 凡是第一参数可为字符串的
local strMeta__Index = getmetatable('').__index
strMeta__Index.split = strMeta__Index.split or split


-- @mod table
-- fields string 'field, ...'
-- return field, ...
local function export(mod, fields)
    local fs = {}
    for f in fields:gmatch('[%w_]+') do
        local v = mod[f]
        if v == nil then
            error('invalid field: ' .. f, 2)
        end
        push(fs, v)
    end
    return unpack(fs)
end

-- NOTE hsq 可用于代替 require
-- @mod string|table
-- return table
local function exportable(mod)
    if type(mod) == 'string' then
        mod = require(mod)
    end
    assert(type(mod) == 'table', 'Invalid module, not exportable')
    local mt = getmetatable(mod)
    if not mt then
        mt = {}
        setmetatable(mod, mt)
    end
    if not mt.__call then
        mt.__call = export
    else
        assert(mt.__call == export, 'Module not exportable')
    end
    return mod
end

-- -- NOTE hsq 语言服务器不能直接跳转文件；虽然不重要，但代码风格上引用关系不够直观。
-- -- @mods string
-- local function new_require(mods)
--     local fs = {}
--     for f in mods:gmatch('[%w_%-.]+') do
--         local v = require(f)
--         if v == nil then
--             error('invalid module: ' .. f, 2)
--         end
--         push(fs, v)
--     end
--     return unpack(fs)
-- end


for _, v in pairs(loaded) do
    if type(v) == 'table' then
        exportable(v)
    end
end

-- package.exportable = exportable
_G.exportable = exportable
-- _G.require    = new_require
_G.extend     = merge


local _M = exportable {
    sh         = sh,
    write_file = write_file,

    push     = push,
    pop      = pop,
    join     = join,

    clear    = clear,
    keys     = keys,
    map      = map,
    clone    = clone,
    merge    = merge,
    readonly = readonly,

    split = split,
}

return _G.extend(_M, api)