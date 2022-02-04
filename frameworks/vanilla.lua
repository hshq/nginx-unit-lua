local require  = require
local dofile   = dofile

local _ENV = {}


return function()
    -- NOTE hsq worker: $(vanilla)/init.lua
    require 'init'
    -- NOTE hsq content: $(demo)/pub/index.lua
    dofile 'pub/index.lua'
end
-- TODO hsq openresty 的响应 header 比 unit 多：
--      Connection: keep-alive
--      Vary: Accept-Encoding