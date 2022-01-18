
local function is_jit()
    return (_VERSION == 'Lua 5.1' and _G.jit) and true or false
end

if _VERSION == 'Lua 5.1' then
    table.unpack = table.unpack or _G.unpack
end

return {
    is_jit = is_jit,
}