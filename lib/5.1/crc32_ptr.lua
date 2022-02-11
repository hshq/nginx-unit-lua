-- from openresty:lib.resty.lrucache.pureffi
local bit = require "bit"

local brshift = bit.rshift
local bxor    = bit.bxor
local band    = bit.band


local function crc32_ptr(p, crc_tab, bucket_mask)
    local b = band(brshift(p, 3), 255)
    local crc32 = crc_tab[b]

    b = band(brshift(p, 11), 255)
    crc32 = bxor(brshift(crc32, 8), crc_tab[band(bxor(crc32, b), 255)])

    b = band(brshift(p, 19), 255)
    crc32 = bxor(brshift(crc32, 8), crc_tab[band(bxor(crc32, b), 255)])

    --b = band(brshift(p, 27), 255)
    --crc32 = bxor(brshift(crc32, 8), crc_tab[band(bxor(crc32, b), 255)])
    return band(crc32, bucket_mask)
end

return crc32_ptr