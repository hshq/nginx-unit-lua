-- XXX 放在系统路径中
-- XXX 加载后，在字符串元表中注册了一些方法

local api = require 'utils_adapter'
-- TODO hsq 改结构为 utils.XX

local type         = type
local pairs        = pairs
local assert       = assert
local getmetatable = getmetatable
local push         = table.insert
local pop          = table.remove
local join         = table.concat
local io_popen     = io.popen


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

local function map(tbl, func)
    for k, v in pairs(tbl) do
        tbl[k] = func(v)
    end
    return tbl
end

-- TODO hsq extend 代替 merge ？
-- 数组部分追加，散列部分覆盖。
local function merge(dst, src)
    -- for k, v in pairs(src) do
    --     dst[k] = v
    -- end
    -- return dst
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

local inited = false
local function init(tz)
    if inited then return end
    inited = true

    -- XXX 凡是第一参数可为字符串的
    local strMeta__Index = getmetatable('').__index
    strMeta__Index.split          = split
end


local _M = {
    init  = init,

    sh = sh,

    push     = push,
    pop      = pop,
    join     = join,
    clear    = clear,
    map      = map,
    merge    = merge,
    readonly = readonly,

    split = split,
}

return merge(_M, api)