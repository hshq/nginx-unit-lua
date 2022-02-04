local dofile = dofile

local _ENV = {}


return function()
    -- NOTE hsq require 保证 METHOD(Location) 只注册一次，重复会报错。
    -- local app = require('app.server')
    -- app:run()
    dofile 'app/main.lua'

    -- -- 测试
    -- local ngx = _G.ngx
    -- local res = ngx.location.capture(
    --     '/hello?a=b', {
    --         args = {a='c',b='d',e={1,2,3}}
    --     }
    -- )
    -- ngx.log(ngx.DEBUG, (require 'inspect')(res))
    -- assert(not res.truncated, 'Subrequest error, response body truncated')
end