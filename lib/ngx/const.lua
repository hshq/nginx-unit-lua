local unit  = require 'lnginx-unit'

local tointeger = math.tointeger

local pairs  = pairs
local ipairs = ipairs


local NGX_LOG_LEVEL = { [0] = 'STDERR',
    'EMERG', 'ALERT', 'CRIT', 'ERR', 'WARN', 'NOTICE', 'INFO', 'DEBUG',
}

-- ngx.HTTP_XX
local NGX_CAPTURE_METHOD = {
    'GET', 'HEAD', 'POST', 'PUT', 'DELETE', 'MKCOL', 'COPY', 'MOVE',
    'OPTIONS', 'PROPFIND', 'PROPPATCH', 'LOCK', 'UNLOCK', 'PATCH', 'TRACE',
}

-- ngx.HTTP_XX
local NGX_HTTP_STATUS = {
    CONTINUE               = 100,
    SWITCHING_PROTOCOLS    = 101,
    OK                     = 200,
    CREATED                = 201,
    ACCEPTED               = 202,
    NO_CONTENT             = 204,
    PARTIAL_CONTENT        = 206,
    SPECIAL_RESPONSE       = 300,
    MOVED_PERMANENTLY      = 301,
    MOVED_TEMPORARILY      = 302,
    SEE_OTHER              = 303,
    NOT_MODIFIED           = 304,
    TEMPORARY_REDIRECT     = 307,
    PERMANENT_REDIRECT     = 308,
    BAD_REQUEST            = 400,
    UNAUTHORIZED           = 401,
    PAYMENT_REQUIRED       = 402,
    FORBIDDEN              = 403,
    NOT_FOUND              = 404,
    NOT_ALLOWED            = 405,
    NOT_ACCEPTABLE         = 406,
    REQUEST_TIMEOUT        = 408,
    CONFLICT               = 409,
    GONE                   = 410,
    UPGRADE_REQUIRED       = 426,
    TOO_MANY_REQUESTS      = 429,
    CLOSE                  = 444,
    ILLEGAL                = 451,
    INTERNAL_SERVER_ERROR  = 500,
    NOT_IMPLEMENTED        = 501,
    METHOD_NOT_IMPLEMENTED = 501, -- (kept for compatibility)
    BAD_GATEWAY            = 502,
    SERVICE_UNAVAILABLE    = 503,
    GATEWAY_TIMEOUT        = 504,
    VERSION_NOT_SUPPORTED  = 505,
    INSUFFICIENT_STORAGE   = 507,
}


local ngx_const = {}

local logs = {}
for level, name in pairs(NGX_LOG_LEVEL) do
    ngx_const[name] = level
    logs[level] = unit[name:lower()] or unit.alert
end

local cap_mtds_id2name = {}
for n, k in ipairs(NGX_CAPTURE_METHOD) do
    n = tointeger(2 ^ n)
    cap_mtds_id2name[n] = k
    ngx_const['HTTP_' .. k] = n
end

local http_status_id2name = {}
for k, n in pairs(NGX_HTTP_STATUS) do
    http_status_id2name[n] = k
    ngx_const['HTTP_' .. k] = n
end

return {
    NGX_LOG_LEVEL = NGX_LOG_LEVEL,

    ngx_const = ngx_const,

    logs                = logs,
    cap_mtds_id2name    = cap_mtds_id2name,
    http_status_id2name = http_status_id2name,
}