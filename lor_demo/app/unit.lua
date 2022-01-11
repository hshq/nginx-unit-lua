#!/usr/bin/env lua5.4

-- 配置可以来自 LUA_INIT_5_4/LUA_INIT 或 unitd 配置参数，后者用法同前者。
--  前者必须设置全局变量 ngx_config ，后者则支持全局变量 ngx_config 和返回配置表。
--      pkill unitd; LUA_INIT_5_4=@conf/config.lor.lua unitd
--      如果 Lua 配置文件中既设置全局变量，也作为返回值，则此处代码无需更改。
local ngx_config = nil
ngx_config, _G.ngx_config = _G.ngx_config, nil

local config    = table.concat({...}, '\n')
local env_init  = os.getenv('LUA_INIT_5_4') or os.getenv('LUA_INIT')

if config ~= env_init or not ngx_config then
    if #config > 0 then
        if config:sub(1, 1) == '@' then
            local path = config:sub(2)
            if #path > 0 then
                ngx_config = assert(loadfile(path))()
            end
        else
            ngx_config = assert(load(config, 'unit args'))()
        end
        ngx_config, _G.ngx_config = (ngx_config or _G.ngx_config), nil
    end
end
assert(ngx_config, 'invalid config')

local unit     = require 'lnginx-unit'
local make_ngx = require 'ngx'


local FAILED = 'Failed!\n'

local function check(ret, rc, err)
    return ret and ret or
        error(('[%d]%s'):format(err or FAILED, err, rc), 2)
end


local function request_handler(req)
    local status = 200

    local ngx = make_ngx(ngx_config, req)
    _G.ngx = ngx
    local app = require('app.server')
    app:run()
    return status, ngx.get_response_content(), ngx.get_response_headers()
end

local ctx = check(unit.init(request_handler))

local ok = check(ctx:run())

ctx:done()
os.exit(true, true)
