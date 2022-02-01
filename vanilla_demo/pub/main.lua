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
    -- _G.ngx = _G.ngx or make_ngx(ngx_cfg, req)

    -- NOTE hsq worker: $(vanilla)/init.lua
    require 'init'
    -- NOTE hsq content: $(demo)/pub/index.lua
    dofile 'pub/index.lua'

    -- local status  = ngx.status or ngx.HTTP_OK
    -- local content = ngx.get_response_content()
    -- local headers = ngx.get_response_headers()

    -- return status, content, headers
end

local function protect_request_handler(req)
    -- TODO hsq 请求之间共享 ngx ，内部状态需要清理！
    -- _G.ngx = _G.ngx or make_ngx(ngx_cfg, req)
    _G.ngx =  make_ngx(ngx_cfg, req)
    local ok, status = pcall(request_handler, req)
    if not ok then
        -- unit.err((require 'inspect'){'status:', status})
        if type(status) == 'table' then
            status = status.status
        else
            -- TODO hsq 报错格式
            status = status:gsub('\\([nt])', {n = '\n', t = '\t'})
            unit.err((require 'inspect'){'status:', package.path, status})
            status = ngx.HTTP_INTERNAL_SERVER_ERROR
        end
    end
    local content = ngx.get_response_content()
    local headers = ngx.get_response_headers()
    return status or ngx.status, content, headers
end
-- TODO hsq openresty 的响应 header 比 unit 多：
--      Connection: keep-alive
--      Vary: Accept-Encoding


local function check(ret, rc, err)
    return ret and ret or
        error(('[%d]%s'):format(err or 'Failed!', err, rc), 2)
end

local ctx = check(unit.init(protect_request_handler))

unit.info(lua_ver)

check(ctx:run())

ctx:done()
os.exit(true, true)