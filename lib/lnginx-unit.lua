local utils = require 'utils'

local _G         = _G
local exportable = _G.exportable

local core  = exportable 'lnginx-unit.core'

local c_log, LOG_LEVEL = core 'log, LOG_LEVEL'
-- local c_req_log = core.req_log

local type, pairs, select, tostring = _G 'type, pairs, select, tostring'


table.new = table.new or core.table_new
package.loaded['table.new'] = table.new


local _ENV = {}


local function check_level(level)
    local lv = level
    if type(lv) == 'string' then
        lv = LOG_LEVEL[lv:upper()]
    end
    if not lv or not LOG_LEVEL[lv] then
        c_log(LOG_LEVEL.ALERT, ('Invalid log level: %s'):format(level))
        return
    end
    return lv
end

-- @level int/string
local function log(level, fmt, ...)
    fmt = tostring(fmt)
    local lv = check_level(level)
    -- TODO hsq DEBUG 应该在 core.log 中处理。
    if lv and (lv ~= LOG_LEVEL.DEBUG or not _G.DEBUG) then
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


local _M = {
    log    = log,
    alert  = make_log(LOG_LEVEL.ALERT),
    err    = make_log(LOG_LEVEL.ERR),
    warn   = make_log(LOG_LEVEL.WARN),
    notice = make_log(LOG_LEVEL.NOTICE),
    info   = make_log(LOG_LEVEL.INFO),
    debug  = make_log(LOG_LEVEL.DEBUG),
}

for k, v in pairs(_M) do
    core[k] = v
end
return exportable(core)