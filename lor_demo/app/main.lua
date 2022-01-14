#!/usr/bin/env lua5.4

-- 配置可以来自 LUA_INIT_5_4(5.4)/LUA_INIT(5.4&jit) 或 unitd 配置参数，后者用法同前者。
--  前者必须设置全局变量 unit_config ，后者则支持全局变量 unit_config 和返回配置表。
--      export LUA_INIT=@conf/config.lor.lua
--      pkill unitd; unitd
--      如果 Lua 配置文件中既设置全局变量，也作为返回值，则此处代码无需更改。
local unit_config
unit_config, _G.unit_config = _G.unit_config, nil

local args = table.concat({...}, '\n')

-- NOTE hsq 自动生效
local env_init
if _G.jit then
    env_init = _G.jit and os.getenv('LUA_INIT')
else
    env_init = os.getenv('LUA_INIT_5_4') or os.getenv('LUA_INIT')
end

-- NOTE hsq 参数配置优先于环境变量
if #args > 0 and (args ~= env_init or not unit_config) then
    if args:sub(1, 1) == '@' then
        local path = args:sub(2)
        if #path > 0 then
            unit_config = assert(loadfile(path))()
        end
    else
        unit_config = assert(load(args, 'unit args'))()
    end
    unit_config, _G.unit_config = (unit_config or _G.unit_config), nil
end
local web_config = assert(unit_config and unit_config.web, 'invalid config')

local unit     = require 'lnginx-unit'
local make_ngx = require 'ngx'

-- unit.debug((require 'inspect'){
--     unit_config = unit_config,
--     unit = unit,
-- })


local FAILED = 'Failed!\n'

local function check(ret, rc, err)
    return ret and ret or
        error(('[%d]%s'):format(err or FAILED, err, rc), 2)
end


local function request_handler(req)
    local status = 200

    local ngx = make_ngx(web_config, req)
    _G.ngx = ngx

    local app = require('app.server')
    app:run()

    -- X-Powered-By 添加 Lua 版本信息
    local ver = _G.jit and (_G.jit.version:match('^(.-)%-')) or _VERSION
    local xpb = ngx.header.x_powered_by
    xpb = xpb and (xpb .. ' on ' .. ver) or ver
    ngx.header.x_powered_by = xpb

    return status, ngx.get_response_content(), ngx.get_response_headers()
end

local ctx = check(unit.init(request_handler))

local ok = check(ctx:run())

ctx:done()
os.exit(true, true)
