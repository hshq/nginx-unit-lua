local utils = require 'utils'

local exportable = exportable
local os_date    = os.date
local os_time    = os.time
local parse_time = utils.parse_time


local _ENV = {}


-- NOTE hsq strftime
-- TODO hsq %G 和 %g 分别对应 %Y 和 %y ，但以周一而不是周日为每周的首日。
-- NOTE hsq https://developer.mozilla.org/zh-CN/docs/Web/HTTP/Headers/Last-Modified
-- GMT: 格林尼治标准时间, UTC: 协调世界时, GMT = UTC+0, CST = UTC+8
local LAST_MODIFIED_FMT = '!%a, %d %b %Y %T %Z'
local PARSE_HTTP_FMT    =  '%a, %d %b %Y %T'
local COOKIE_TIME_FMT   = '!%a, %d-%b-%y %T %Z'


-- 如用于 Last-Modified
-- @ts? 时间戳
local function http_time(ts)
    return os_date(LAST_MODIFIED_FMT, ts)
end

local function cookie_time(ts)
    return os_date(COOKIE_TIME_FMT, ts)
end

local function parse_http_time(str)
    return parse_time(str, PARSE_HTTP_FMT)
end

-- {{{
-- TODO hsq 缓冲时间，自动或手动更新，无系统调用；检查调用处。
--      unit 似乎有类似实现，搜索 nxt_thread_time_update

-- 强制更新时间缓冲，慎用
local function update_time()
    return nil, 'update_time: TODO hsq'
end

-- 本地时间 yyyy-mm-dd
local function today()
    return os_date('%F') -- %Y-%m-%d
end

local time = os_time

-- @all? 缺省 false ，返回当前时间戳，浮点数，<秒.毫秒>；
--      true 则返回 秒 微秒 本地时区 是否有夏令时(并非现在处于)
--      本地时区：以格林威治为基准，西向为正，分钟为单位。
local now = utils.now

-- 本地时间 yyyy-mm-dd hh:mm:ss
local function localtime()
    return os_date('%F %T') -- %Y-%m-%d %H:%M:%S
end

-- UTC 时间 yyyy-mm-dd hh:mm:ss
local function utctime()
    return os_date('!%F %T') -- %Y-%m-%d %H:%M:%S
end
-- }}}

return exportable {
    update_time     = update_time,
    time            = time,
    now             = now,
    localtime       = localtime,
    utctime         = utctime,
    today           = today,
    http_time       = http_time,
    cookie_time     = cookie_time,
    parse_http_time = parse_http_time,
}