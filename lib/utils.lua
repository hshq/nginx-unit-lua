local utils = require 'utils_base'
utils.init()
-- utils.init= nil
local merge = utils.merge

merge(utils, require 'utils_ffi')

local b64 = require 'lbase64'
-- NOTE hsq auto 可能使用 neon32/neon64 导致编解码失败。
b64.set_codec(b64.codec.avx2)
utils.encode_base64 = b64.encode
utils.decode_base64 = b64.decode


local type     = type
local pairs    = pairs
local ipairs   = ipairs
local tonumber = tonumber
local char     = string.char
local push     = utils.insert


local function unescape(str)
    return str:gsub('+', ' '):gsub('%%(%w%w)',
        function(code)
            return char(tonumber(code, 16))
        end)
end

-- @max_args: nil|N>=0
local function parseQuery(query, max_args)
    local args = {}
    if not query or type(query) ~= 'string' then
        return args
    end
    local ps = query:split('&', max_args, true)
    for i, p in ipairs(ps) do
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

merge(utils, {
    parseQuery = parseQuery,
})

return utils