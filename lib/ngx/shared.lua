local ngx_const    = require 'ngx.const'
local ngx_datetime = require 'ngx.datetime'

local calc_units = ngx_const.calc_units
local now        = ngx_datetime.now

local type = type


local config = {}

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
        if not config[k] then
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

local function init(cfg)
    local min_shared_dict = calc_units(cfg.MIN_SHARED_DICT)
    if (cfg.shared_dict) then
        for k, v in pairs(cfg.shared_dict) do
            v = calc_units(v)
            v = v < min_shared_dict and min_shared_dict or v
            config[k] = v
        end
    end
    return shared
end

return init