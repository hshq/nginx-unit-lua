
local require = require

local base  = require 'utils.base'
local pjson = require 'utils.prettify_json'

local extend     = extend
local exportable = exportable
-- local _G = _G

local type, assert, pairs, ipairs, tonumber, tostring, string =
    _G 'type, assert, pairs, ipairs, tonumber, tostring, string'
local char, upper = string 'char, upper'
local push, join = base 'push, join'


local _ENV = {}


local _M = exportable {
    pjson = pjson,
}

extend(_M, (require 'utils.ffi'))
extend(_M, base)
extend(_M, (require 'lcodec'))
-- NOTE hsq auto 可能使用 neon32/neon64 导致编解码失败。
_M.set_base64_codec(_M.base64_codec.avx2)


local md5 = _M.md5


function _M.md5_bin(str)
    return md5(str, true)
end


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
local char2escape_uri_f    = char2escape(escape_charset.U_F)
local char2escape_uri_c    = char2escape(escape_charset.U_C)

-- NOTE hsq 注意 gsub 返回匹配数作为第二个结果

function _M.escape_header_k(k)
    return (k:gsub('.', char2escape_header_k))
end

function _M.escape_header_v(v)
    return (tostring(v):gsub('.', char2escape_header_v))
end

-- @typ? 2: 作为 URI 部件, 0: 作为完整 URI
local function escape_uri(str, typ)
    str = tostring(str)
    if not typ or typ == 2 then
        return (str:gsub('.', char2escape_uri_c))
    elseif typ == 0 then
        return (str:gsub('.', char2escape_uri_f))
    end
end
_M.escape_uri = escape_uri

-- @str 已转义的 URI 部件
local function unescape_uri(str)
    -- 无效转义序列： % 和 不该出现在已转义字串中的字符不变：
    return (str:gsub('+', ' '):gsub('%%([0-9a-fA-F][0-9a-fA-F])',
        function(code)
            return char(tonumber(code, 16))
        end))
end
_M.unescape_uri = unescape_uri

function _M.normalize_header(name)
    return name:lower():gsub('_', '-'):gsub('%f[%w]%w', upper)
end

function _M.flatten_header(name)
    return name:lower():gsub('-', '_')
end

-- @args table
-- return string
function _M.encode_args(args)
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

-- @max_args: N>=0|nil|false
-- return table, msg?
function _M.parseQuery(query, max_args)
    local args = {}
    if not query or type(query) ~= 'string' then
        return args
    end
    local ps = query:split('&', (max_args and max_args + 1), true);
    for i, p in ipairs(ps) do
        if max_args and i > max_args then
            return args, 'truncated'
        end
        local k, eq, v = p:match('^([^=]+)(=?)(.*)$')
        k = k and unescape_uri(k) or k
        v = v and unescape_uri(v) or v
        v = eq == '' and true or v
        if k then
            local v0 = args[k]
            if not v0 then
                args[k] = v
            else
                v0 = type(v0) == 'table' and v0 or {v0}
                push(v0, v)
                args[k] = v0
            end
        end
    end
    return args
end


return _M