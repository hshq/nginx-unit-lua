
local _VERSION = _VERSION
-- local package  = package
local table    = table
local math     = math
local _G       = _G

local floor = math.floor


local _ENV = {}


-- 纯粹为了避免语言服务器提示问题
local function get_global(name)
    return _G[name]
end

local is_jit = (_VERSION == 'Lua 5.1' and _G['jit']) and true or false

if _VERSION == 'Lua 5.1' then

    table.unpack = table.unpack or get_global('unpack')

    math.tointeger = math.tointeger or
        function(num)
            local int = floor(num)
            return int == num and int or nil
        end

else

    -- package.loaded['bit'] = package.loaded['bit'] or {
    --     rshift = function(a, b) return a >> b end,
    --     bxor   = function(a, b) return a |  b end,
    --     band   = function(a, b) return a &  b end,
    -- }

end

local what = is_jit and (_G['jit'].version:match('^(.-)%-')) or _VERSION

return {
    is_jit = is_jit,
    what   = what,
}