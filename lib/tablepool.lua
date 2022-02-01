-- from openresty
-- 每个 tag 命名一个池，缓存对象为 表，栈式存取，
--  若有则用，无则新建(narr&nrec 为其属性)：
--  [0] 是其中对象数，上限 200 ，超过则丢弃对象；
--  .c 是使用计数，上限 20000 ，超过则丢弃重建空池；
-- TODO hsq require "table.clear, table.new"
local newtab = require "table.new"
local cleartab = require "table.clear"
local setmetatable = setmetatable


local _M = newtab(0, 2)
local max_pool_size = 200
local pools = newtab(0, 4)


function _M.fetch(tag, narr, nrec)
    local pool = pools[tag]
    if not pool then
        pool = newtab(4, 1)
        pools[tag] = pool
        pool.c = 0
        pool[0] = 0

    else
        local len = pool[0]
        if len > 0 then
            local obj = pool[len]
            pool[len] = nil
            pool[0] = len - 1
            -- ngx.log(ngx.ERR, "HIT")
            return obj
        end
    end

    return newtab(narr, nrec)
end


function _M.release(tag, obj, noclear)
    if not obj then
        error("object empty", 2)
    end

    local pool = pools[tag]
    if not pool then
        pool = newtab(4, 1)
        pools[tag] = pool
        pool.c = 0
        pool[0] = 0
    end

    if not noclear then
        setmetatable(obj, nil)
        cleartab(obj)
    end

    do
        local cnt = pool.c + 1
        if cnt >= 20000 then
            pool = newtab(4, 1)
            pools[tag] = pool
            pool.c = 0
            pool[0] = 0
            return
        end
        pool.c = cnt
    end

    local len = pool[0] + 1
    if len > max_pool_size then
        -- discard it simply
        return
    end

    pool[len] = obj
    pool[0] = len
end


return _M

-- vi: ft=lua ts=4 sw=4 et
