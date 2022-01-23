-- 无状态函数原型
local cjson     = require 'cjson'
local utils     = require 'utils'
local ngx_const = require 'ngx.const'
local unit      = require 'lnginx-unit'

local type     = type
local tonumber = tonumber
local char     = string.char
local upper    = string.upper
local os_date  = os.date

local null = cjson.null

local NGX_LOG_LEVEL = ngx_const.NGX_LOG_LEVEL
local logs          = ngx_const.logs

local push = utils.push
local join = utils.join

local md5 = unit.md5


-- NOTE hsq strftime
-- NOTE hsq https://developer.mozilla.org/zh-CN/docs/Web/HTTP/Headers/Last-Modified
local LAST_MODIFIED_FMT = '!%a, %d %b %Y %T GMT'

local function http_time(ts)
    return os_date(LAST_MODIFIED_FMT, ts)
end


-- NOTE 转义字符范围，从 openresty 响应头实验中汇集。
local escape_charset = {
    [0] = '21,23-27,2A,2B,2D,2E,30-39,41-5A,5E-7A,7C,7E',   -- 都不转
    [1] = '9,20,22,28-29,2C,2F,3A-40,5B-5D,7B,7D,80-FF',    -- 只 K 转
    [2] = '0-8,A-1F,7F',                                    -- KV 都转
    K   = '0-20,22,28-29,2C,2F,3A-40,5B-5D,7B,7D,7F-FF',    -- K 转
    V   = '0-8,A-1F,7F',                                    -- V 转
}
local escape_charset_v = {}
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
local char2escape_k = char2escape(escape_charset.K)
local char2escape_v = char2escape(escape_charset.V)

local function escape_k(k)
    return (k:gsub('.', char2escape_k)) -- 只返回首值
end
local function escape_v(v)
    return (tostring(v):gsub('.', char2escape_v)) -- 只返回首值
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
        k = escape_k(k)
        -- {k = true} -> k
        -- {k = false} ->
        if v == true then
            push(buf, k)
        elseif v ~= false then
            local v_t = type(v)
            -- {k = str|num} -> k=v
            if v_t == 'string' or v_t == 'number' then
                 push(buf, ('%s=%s'):format(k, escape_v(v)))
            elseif v_t == 'table' then
                -- {k = {v1, v2...}} -> k=v1&k=v2...
                -- {k = {}} ->
                for _, v2 in ipairs(v) do
                    push(buf, ('%s=%s'):format(k, escape_v(v2)))
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


return {
    null = null,

    decode_base64 = utils.decode_base64,
    encode_base64 = utils.encode_base64,

    time      = os.time,
    http_time = http_time,

    escape_k         = escape_k,
    escape_v         = escape_v,
    normalize_header = normalize_header,
    flatten_header   = flatten_header,
    encode_args      = encode_args,

    log         = log,
    get_phase   = get_phase,

    md5 = md5,
    md5_bin = md5_bin,
}