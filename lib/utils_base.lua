-- XXX 放在系统路径中
-- XXX 加载后，在字符串元表中注册了一些方法

local type         = type
local pairs        = pairs
local getmetatable = getmetatable
local push         = table.insert
local pop          = table.remove
local join         = table.concat


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

local function merge(dst, src)
    for k, v in pairs(src) do
        dst[k] = v
    end
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


return {
    init  = init,

    push  = push,
    pop   = pop,
    join  = join,
    clear = clear,
    map   = map,
    merge = merge,
    split = split,
}