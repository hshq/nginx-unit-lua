local ngx_datetime = require 'ngx.datetime'

local now = ngx_datetime.now

local type = type


-- TODO hsq 多进程共享；更高性能的实现；
local shared = {}

local stores = {}
local timers = {} -- expire_at

local dict_meta
dict_meta = {
    -- value, flags = ngx.shared.DICT:get(key)
    get = function (t, k)
        if type(k) ~= 'string' then return false, 'Invalid Key Type' end
        local v = stores[t][k]
        if v then
            local expire_at = timers[t][k]
            if expire_at and expire_at <= now() then
                v = nil
                stores[t][k] = nil
                timers[t][k] = nil
            end
        end
        return v
    end,
    -- success, err, forcible = ngx.shared.DICT:set(key, value, exptime?, flags?)
    set = function (t, k, v, expire)
        -- TODO hsq 增加时检查占用量；如何定时检查过期？
        if type(k) ~= 'string' then return false, 'Invalid Key Type' end
        stores[t][k] = v
        timers[t][k] = (v ~= nil and expire > 0) and now() + expire or nil
        return true
    end,
    __index = function(t, k)
        local function todo(...)
            return nil, 'TODO hsq: ngx.shared:' .. k
        end
        return dict_meta[k] or todo
    end,
}
setmetatable(shared, {
    __index = function(t, k)
        -- TODO hsq 隐藏 ngx.shared_dict
        if not ngx.shared_dict[k] then
            return nil
        end
        local dict, store, timer = {}, {}, {}
        stores[dict] = store
        timers[dict] = timer
        setmetatable(dict, dict_meta)
        t[k] = dict
        return dict
    end,
})

return {
    shared = shared
}