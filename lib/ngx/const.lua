local cjson = require 'cjson'
local unit  = require 'lnginx-unit'

local exportable = exportable
local tointeger  = math.tointeger
local pairs, ipairs, error, tonumber = _G 'pairs, ipairs, error, tonumber'


local _ENV = {}


local CORE = {
    -- NULL light userdata
    null = cjson.null,
    -- NOTE hsq Nginx API for Lua 只用其中 3 个，如
    --      ngx.exit 只用 OK ERROR DECLINED
    -- NOTE hsq 建议只用 OK 和 ERROR
    --      https://forum.openresty.us/d/4257-dc5f7368d6c0b220039fbbc71ed87bce
    OK       = 0,
    ERROR    = -1,
    AGAIN    = -2,
    DONE     = -4,
    DECLINED = -5,
}


local LOG_LEVEL_VEC = { [0] = 'STDERR',
    'EMERG', 'ALERT', 'CRIT', 'ERR', 'WARN', 'NOTICE', 'INFO', 'DEBUG',
}
local LOG_LEVEL = {} -- name -> id

-- ngx.HTTP_XX
local CAPTURE_METHOD_VEC = {
    'GET', 'HEAD', 'POST', 'PUT', 'DELETE', 'MKCOL', 'COPY', 'MOVE',
    'OPTIONS', 'PROPFIND', 'PROPPATCH', 'LOCK', 'UNLOCK', 'PATCH', 'TRACE',
}
local CAPTURE_METHOD = {} -- name -> id

-- ngx.HTTP_XX
local HTTP_STATUS = {
    HTTP_CONTINUE               = 100,
    HTTP_SWITCHING_PROTOCOLS    = 101,
    HTTP_OK                     = 200,
    HTTP_CREATED                = 201,
    HTTP_ACCEPTED               = 202,
    HTTP_NO_CONTENT             = 204,
    HTTP_PARTIAL_CONTENT        = 206,
    HTTP_SPECIAL_RESPONSE       = 300,
    HTTP_MOVED_PERMANENTLY      = 301,
    HTTP_MOVED_TEMPORARILY      = 302,
    HTTP_SEE_OTHER              = 303,
    HTTP_NOT_MODIFIED           = 304,
    HTTP_TEMPORARY_REDIRECT     = 307,
    HTTP_PERMANENT_REDIRECT     = 308,
    HTTP_BAD_REQUEST            = 400,
    HTTP_UNAUTHORIZED           = 401,
    HTTP_PAYMENT_REQUIRED       = 402,
    HTTP_FORBIDDEN              = 403,
    HTTP_NOT_FOUND              = 404,
    HTTP_NOT_ALLOWED            = 405,
    HTTP_NOT_ACCEPTABLE         = 406,
    HTTP_REQUEST_TIMEOUT        = 408,
    HTTP_CONFLICT               = 409,
    HTTP_GONE                   = 410,
    HTTP_UPGRADE_REQUIRED       = 426,
    HTTP_TOO_MANY_REQUESTS      = 429,
    HTTP_CLOSE                  = 444,
    HTTP_ILLEGAL                = 451,
    HTTP_INTERNAL_SERVER_ERROR  = 500,
    HTTP_NOT_IMPLEMENTED        = 501,
    HTTP_METHOD_NOT_IMPLEMENTED = 501, -- (kept for compatibility)
    HTTP_BAD_GATEWAY            = 502,
    HTTP_SERVICE_UNAVAILABLE    = 503,
    HTTP_GATEWAY_TIMEOUT        = 504,
    HTTP_VERSION_NOT_SUPPORTED  = 505,
    HTTP_INSUFFICIENT_STORAGE   = 507,
}

local REDIRECT_STATUS = { -- Set
    [HTTP_STATUS.HTTP_MOVED_PERMANENTLY]  = true,
    [HTTP_STATUS.HTTP_MOVED_TEMPORARILY]  = true,
    [HTTP_STATUS.HTTP_NOT_MODIFIED]       = true,
    [HTTP_STATUS.HTTP_TEMPORARY_REDIRECT] = true,
    [HTTP_STATUS.HTTP_PERMANENT_REDIRECT] = true,
}

local logs = {}  -- level -> function
for level, name in pairs(LOG_LEVEL_VEC) do
    LOG_LEVEL[name] = level
    logs[level] = unit[name:lower()] or unit.alert
end

local cap_mtds_id2name = {}
for n, k in ipairs(CAPTURE_METHOD_VEC) do
    n = tointeger(2 ^ n)
    cap_mtds_id2name[n] = k
    CAPTURE_METHOD['HTTP_' .. k] = n
end

local http_status_id2name = {}
for k, n in pairs(HTTP_STATUS) do
    http_status_id2name[n] = k
end


local UNITS = {
    k = 2^10, K = 2^10,
    m = 2^20, M = 2^20,
    -- g = 2^30, G = 2^30,
}

local function calc_units(str)
    local val, uni = str:match('^(%d+)([kKmMgG])$')
    val = tointeger(tonumber(val))
    uni = uni and UNITS[uni]
    val = val and uni and val * uni
    if not val or val < 0 then
        error(('Invalid configuration: %s'):format(str), 2)
    end
    return val
end


return exportable {
    CORE           = CORE,
    HTTP_STATUS    = HTTP_STATUS,
    LOG_LEVEL      = LOG_LEVEL,
    CAPTURE_METHOD = CAPTURE_METHOD,

    REDIRECT_STATUS = REDIRECT_STATUS,

    logs                = logs,
    cap_mtds_id2name    = cap_mtds_id2name,
    http_status_id2name = http_status_id2name,

    calc_units = calc_units,
}