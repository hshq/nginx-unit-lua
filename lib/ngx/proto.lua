-- 无状态函数原型
local utils     = require 'utils'
local ngx_const = require 'ngx.const'
local unit      = require 'lnginx-unit'

local type     = type
local tonumber = tonumber
local char     = string.char
local upper    = string.upper
local os_date  = os.date

local NGX_LOG_LEVEL = ngx_const.NGX_LOG_LEVEL
local logs          = ngx_const.logs
local null          = ngx_const.null

local push       = utils.push
local join       = utils.join
local md5        = utils.md5
local parse_time = utils.parse_time


-- NOTE hsq strftime
-- TODO hsq %G 和 %g 分别对应 %Y 和 %y ，但以周一而不是周日为每周的首日。
-- NOTE hsq https://developer.mozilla.org/zh-CN/docs/Web/HTTP/Headers/Last-Modified
-- GMT: 格林尼治标准时间, UTC: 协调世界时, GMT = UTC+0, CST = UTC+8
local LAST_MODIFIED_FMT = '!%a, %d %b %Y %T %Z'
local PARSE_HTTP_FMT    =  '%a, %d %b %Y %T'
local COOKIE_TIME_FMT   = '!%a, %d-%b-%y %T %Z'

-- 如用于 Last-Modified
local function http_time(ts)
    return os_date(LAST_MODIFIED_FMT, ts)
end

local function cookie_time(ts)
    return os_date(COOKIE_TIME_FMT, ts)
end

local function parse_http_time(str)
    return parse_time(str, PARSE_HTTP_FMT)
end

-- {{{ TODO hsq 缓冲时间，自动或手动更新，无系统调用；检查调用处。
--      unit 似乎有类似实现，搜索 nxt_thread_time_update

-- 强制更新时间缓冲，慎用
local function update_time()
    return nil, 'update_time: TODO hsq'
end

-- 本地时间 yyyy-mm-dd
local function today()
    return os_date('%F') -- %Y-%m-%d
end

local time = os.time

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


-- NOTE 转义字符范围，从 openresty 响应头实验中汇集。
local escape_charset = {
    [0] = '21,23-27,2A,2B,2D,2E,30-39,41-5A,5E-7A,7C,7E',   -- header: 都不转
    [1] = '9,20,22,28-29,2C,2F,3A-40,5B-5D,7B,7D,80-FF',    -- header: 只 K 转
    [2] = '0-8,A-1F,7F',                                    -- header: KV 都转
    H_K = '0-20,22,28-29,2C,2F,3A-40,5B-5D,7B,7D,7F-FF',    -- header: K 转
    H_V = '0-8,A-1F,7F',                                    -- header: V 转

    U_F = '0-1F,20,23,25,3F,7F-FF',                             -- 完整 URI
    U_C = '0-1F,20,22-26,2B,2C,2F,3A-40,5B-5E,60,7B-7D,7F-FF',  -- URI 部件
}
local function char2escape(charset)
    local c2e = {}
    charset:gsub('[^,]+', function(set)
        local s, e = set:match('(%w+)%-?(%w*)')
        s = tonumber(s, 16)
        e = (e and e ~= '') and tonumber(e, 16) or s
        for b = s, e do
            c2e[char(b)] = ('%%%02X'):format(b)
        end
    end)
    return c2e
end
local char2escape_header_k = char2escape(escape_charset.H_K)
local char2escape_header_v = char2escape(escape_charset.H_V)
local char2escape_uri_f = char2escape(escape_charset.U_F)
local char2escape_uri_c = char2escape(escape_charset.U_C)

-- NOTE hsq 注意 gsub 返回匹配数作为第二个结果

local function escape_header_k(k)
    return (k:gsub('.', char2escape_header_k))
end
local function escape_header_v(v)
    return (tostring(v):gsub('.', char2escape_header_v))
end

-- @typ? 2: 作为 URI 部件, 0: 作为完整 URI
local function escape_uri(str, typ)
    if not typ or typ == 2 then
        return (str:gsub('.', char2escape_uri_c))
    elseif typ == 0 then
        return (str:gsub('.', char2escape_uri_f))
    end
end
-- @str 已转义的 URI 部件
local function unescape_uri(str)
    -- 无效转义序列： % 和 不该出现在已转义字串中的字符不变：
    return (str:gsub('+', ' '):gsub('%%([0-9a-fA-F])([0-9a-fA-F])', function(a, b)
        return char(tonumber(a, 16) * 16 + tonumber(b, 16))
    end))
end

local function normalize_header(name)
    return name:lower():gsub('_', '-'):gsub('%f[%w]%w', upper)
end
local function flatten_header(name)
    return name:lower():gsub('-', '_')
end


-- @args table
-- return string
local function encode_args(args)
    assert(type(args) == 'table', 'Invalid parameter')
    local buf = {}
    for k, v in pairs(args) do
        assert(type(k) == 'string', 'Invalid KEY type')
        k = escape_uri(k)
        -- {k = true} -> k
        -- {k = false} ->
        if v == true then
            push(buf, k)
        elseif v ~= false then
            local v_t = type(v)
            -- {k = str|num} -> k=v
            if v_t == 'string' or v_t == 'number' then
                 push(buf, ('%s=%s'):format(k, escape_uri(v)))
            elseif v_t == 'table' then
                -- {k = {v1, v2...}} -> k=v1&k=v2...
                -- {k = {}} ->
                for _, v2 in ipairs(v) do
                    push(buf, ('%s=%s'):format(k, escape_uri(v2)))
                end
            end
        end
    end
    return join(buf, '&')
end

local function log(level, ...)
    local name = NGX_LOG_LEVEL[level]
    local args = {...}
    for i, arg in ipairs(args) do
        args[i] = arg == null and 'null' or tostring(arg)
    end
    -- NOTE hsq join 得到的字串中可能含有 % 字符，若置于 fmt 参数位置会报错（缺少参数）。
    logs[level]('%s', join(args))
end

local function get_phase()
    -- NOTE hsq 只支持 content ？ unit 不区分 phase ？
    return 'content'
end

local function md5_bin(str)
    return md5(str, true)
end


-- TODO hsq 多进程共享；更高性能的实现；独立模块？
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
    -- TODO hsq 不经过 utils ，直接引入？
    decode_base64 = utils.decode_base64,
    encode_base64 = utils.encode_base64,
    md5           = md5,
    md5_bin       = md5_bin,
    crc32         = utils.crc32,
    crc32_short   = utils.crc32,
    crc32_long    = utils.crc32,

    update_time = update_time,
    time        = time,
    now         = now,
    localtime   = localtime,
    utctime     = utctime,
    today       = today,
    http_time   = http_time,
    cookie_time = cookie_time,
    parse_http_time = parse_http_time,

    escape_header_k  = escape_header_k,
    escape_header_v  = escape_header_v,
    escape_uri       = escape_uri,
    unescape_uri     = unescape_uri,
    normalize_header = normalize_header,
    flatten_header   = flatten_header,
    encode_args      = encode_args,

    log         = log,
    get_phase   = get_phase,

    shared = shared,
}