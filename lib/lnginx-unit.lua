
local core = require 'lnginx-unit.core'

local c_log     = core.log
-- local c_req_log = core.req_log
local LOG_LEVEL = core.LOG_LEVEL
local c_init    = core.init

local type   = type
local select = select

local function check_level(level)
    local lv = level
    if type(lv) == 'string' then
        lv = LOG_LEVEL[lv:upper()]
    end
    if not lv or not LOG_LEVEL[lv] then
        c_log(LOG_LEVEL.ALERT, ('log 等级无效：%s'):format(level))
        return
    end
    return lv
end

-- @level int/string
local function log(level, fmt, ...)
    local lv = check_level(level)
    if lv then
        if select('#', ...) == 0 then
            -- NOTE hsq fmt 中可能有 % 字符: bad argument #1 to 'format' (no value)
            -- TODO hsq 以及 ngx.log
            c_log(lv, fmt)
        else
            c_log(lv, fmt:format(...))
        end
    end
end

local function make_log(level)
    return function (fmt, ...)
        return log(level, fmt, ...)
    end
end


local mod = {
    log    = log,
    alert  = make_log(LOG_LEVEL.ALERT),
    err    = make_log(LOG_LEVEL.ERR),
    warn   = make_log(LOG_LEVEL.WARN),
    notice = make_log(LOG_LEVEL.NOTICE),
    info   = make_log(LOG_LEVEL.INFO),
    debug  = make_log(LOG_LEVEL.DEBUG),
}
if not _G.DEBUG then
    mod.debug = function(...) end
end

for k, v in pairs(mod) do
    core[k] = v
end
return core