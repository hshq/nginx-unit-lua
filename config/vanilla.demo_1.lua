#!/usr/bin/env lua5.4

-- NOTE hsq unit.debug(...) 开关。
local DEBUG   = true

local USE_JIT = false
-- if _G.USE_JIT ~= nil then
--     USE_JIT = _G.USE_JIT
-- end

local app = _G.app


local _ENV = {}


local config = {}

config.app = {
    DEBUG  = DEBUG,
    -- NOTE hsq nginx/openresty 命令的 -p 选项设定的值
    prefix = app.dir,
    set_vars = {
        APP_NAME        = 'vanilla_demo',
        VANILLA_VERSION = '0_1_0_rc7',
        VANILLA_ROOT    = app.framework.lib,
        -- lua-resty-template
        template_root   = '',
        -- template_cache  = 'on', -- nil==true/'true'/'on'/'1',
        va_cache_status = '',
        -- -- 如设置则利用 ngx.location.capture 获取模版，否则从文件（获取失败也是）。
        -- template_location = '',   -- nil==''
        -- -- lua-resty-session/lua-resty-aes ，都应用缺省值
        -- session_aes_size   = '',
        -- session_aes_mode   = '',
        -- session_aes_hash   = '',
        -- session_aes_rounds = '',
        -- TODO hsq $VA_DEV
        -- VA_DEV          = 'on',
    },
    -- TODO hsq shared_dict 应该是多 App 共享的
    shared_dict = {
        idevz = '20m',
    },
}

config.ngx = {
    DEFAULT_ROOT         = '',
    MAX_ARGS             = 64,
    HTTP_MAX_SUBREQUESTS = 8,
    MIN_SHARED_DICT      = '12k',
}

config.vhost = {
    listeners = { ['*:5555'] = { pass = 'routes/' .. app.name, },},
    applications = {
        [app.name] = {
            type              = 'external',
            processes         = 1,
            working_directory = app.dir,
            executable        = app.executable(USE_JIT),
            arguments         = { app.unit.entry, 'run', app.name },
        },},
    routes = {
        [app.name] = {
            {   match  = { uri = {'*.ico'} },
                action = { share = 'pub/$uri', },},
            {   action = { pass = 'applications/' .. app.name, },},
        },},}

return config