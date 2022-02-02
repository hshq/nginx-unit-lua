#!/usr/bin/env lua5.4


local unit_config = _G.unit_config
_G.unit_config = nil

local app_config = assert(unit_config and unit_config.app, 'invalid config')
_G.DEBUG = app_config.DEBUG

local utils    = require 'utils'
local unit     = require 'lnginx-unit'
local make_ngx = require 'ngx'

local ngx_cfg = (require 'ngx.config')(unit_config)


local lua_ver = utils.is_jit and (_G['jit'].version:match('^(.-)%-')) or _VERSION


local function request_handler(req)
    _G.ngx = make_ngx(ngx_cfg, req)

    -- NOTE hsq require 保证 METHOD(Location) 只注册一次，重复会报错。
    -- local app = require('app.server')
    -- app:run()
    dofile 'app/main.lua'


    -- -- 测试
    -- local res = ngx.location.capture(
    --     '/hello?a=b', {
    --         args = {a='c',b='d',e={1,2,3}}
    --     }
    -- )
    -- unit.debug((require 'inspect')(res))
    -- assert(not res.truncated, 'Subrequest error, response body truncated')

    -- 测试
    -- X-Powered-By 添加 Lua 版本信息
    local xpb = ngx.header.x_powered_by
    -- xpb = xpb and (xpb .. ' on ' .. lua_ver) or lua_ver
    xpb = xpb and {xpb, lua_ver} or lua_ver
    ngx.header.x_powered_by = xpb


    local status  = ngx.status or ngx.HTTP_OK
    local content = ngx.get_response_content()
    local headers = ngx.get_response_headers()

    return status, content, headers
end


local function check(ret, rc, err)
    return ret and ret or
        error(('[%d]%s'):format(err or 'Failed!', err, rc), 2)
end

local ctx = check(unit.init(request_handler))

unit.info(lua_ver)

check(ctx:run())

ctx:done()
os.exit(true, true)