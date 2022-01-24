local base = require 'utils.base'
base.init()
-- base.init= nil
local merge = base.merge

local _M = {}

merge(_M, base)
merge(_M, (require 'lbase64'))
-- NOTE hsq auto 可能使用 neon32/neon64 导致编解码失败。
_M.set_base64_codec(_M.base64_codec.avx2)


local type     = type
local pairs    = pairs
local ipairs   = ipairs
local tonumber = tonumber
local char     = string.char
local push     = base.push


local function unescape(str)
    return str:gsub('+', ' '):gsub('%%(%w%w)',
        function(code)
            return char(tonumber(code, 16))
        end)
end

-- @max_args: N>=0|nil|false
-- return table, msg?
local function parseQuery(query, max_args)
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
        k = k and unescape(k) or k
        v = v and unescape(v) or v
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


_M.parseQuery = parseQuery

return _M