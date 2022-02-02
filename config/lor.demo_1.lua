#!/usr/bin/env lua5.4

-- NOTE hsq unit.debug(...) 开关。
local DEBUG   = true

local USE_JIT = true
-- if _G.USE_JIT ~= nil then
--     USE_JIT = _G.USE_JIT
-- end

local app = _G.app

-- TODO hsq 编译、运行时给每个 chunk 加入文件名常量？

local config = {}

config.app = {
    DEBUG  = DEBUG,
    -- NOTE hsq nginx/openresty 命令的 -p 选项设定的值
    prefix = app.dir,
    set_vars = {
        -- lua-resty-template
        template_root     = '',
        template_cache    = 'on', -- nil==true/'true'/'on'/'1',
        -- 如设置则利用 ngx.location.capture 获取模版，否则从文件（获取失败也是）。
        template_location = '',   -- nil==''
        -- lua-resty-session/lua-resty-aes ，都应用缺省值
        session_aes_size   = '',
        session_aes_mode   = '',
        session_aes_hash   = '',
        session_aes_rounds = '',
    },
}

config.ngx = {
    -- DEFAULT_ROOT         = 'html',
    MAX_ARGS             = 64,
    HTTP_MAX_SUBREQUESTS = 8,
}

config.vhost = {
    -- TODO hsq 支持环境变量 LOR_ENV=env ？
    -- TODO hsq 端口号来自 lib.lor.bin.scaffold.nginx.config ，生成 web 和运行都是。
    listeners = { ['*:8888'] = { pass = 'routes/' .. app.name, },},
    applications = {
        [app.name] = {
            type              = 'external',
            processes         = 1,

            -- NOTE hsq cwd/pwd 默认在 unit 启动时的路径，
            --      配置中的 working_directory 可覆盖，并作用于静态资源。
            working_directory = app.dir,

            -- executable        = 'app/main.lua',
            -- arguments         = {'@' .. cfg_file},

            -- executable        = app.executable(USE_JIT),
            -- -- arguments         = { 'app/main.lua', '@' .. cfg_file },
            -- arguments         = { 'app/main.lua', app.name },

            -- working_directory = app.unit.dir,
            executable        = app.executable(USE_JIT),
            arguments         = { app.unit.entry, 'run', app.name },
        },},
    routes = {
        [app.name] = {
            {   match  = { uri = {'*.ico'} },
                action = { share = 'app/static$uri', },},
            {   match  = { uri = '~^/.*$', }, -- '~^/(hello)?$'
                action = { pass = 'applications/' .. app.name, },},
        },},}

return config