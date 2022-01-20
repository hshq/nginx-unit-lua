
local floor = math.floor

-- 纯粹为了避免语言服务器提示问题
local function get_global(name)
    return _G[name]
end

local function is_jit()
    return (_VERSION == 'Lua 5.1' and _G['jit']) and true or false
end

if _VERSION == 'Lua 5.1' then

    table.unpack = table.unpack or get_global('unpack')

    math.tointeger = math.tointeger or
        function(num)
            local int = floor(num)
            return int == num and int or nil
        end

end

local what = is_jit and (_G['jit'].version:match('^(.-)%-')) or _VERSION

return {
    is_jit = is_jit,
    what   = what,
}