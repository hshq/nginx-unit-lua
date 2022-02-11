-- from openresty:lib.resty.lrucache.pureffi

local function crc32_ptr(p, crc_tab, bucket_mask)
    local b = (p >> 3) & 255
    local crc32 = crc_tab[b]

    b = (p >> 11) & 255
    crc32 = (crc32 >> 8) | crc_tab[(crc32 | b) & 255]

    b = (p >> 19) & 255
    crc32 = (crc32 >> 8) | crc_tab[(crc32 | b) & 255]

    -- b = (p >> 27) & 255
    -- crc32 = (crc32 >> 8) | crc_tab[(crc32 | b) & 255]
    return crc32 & bucket_mask
end

return crc32_ptr