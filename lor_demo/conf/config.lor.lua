#!/usr/bin/env lua5.4

-- NOTE hsq unit.debug(...) 开关。
local DEBUG = true

local USE_JIT = true
if _G.USE_JIT ~= nil then
    USE_JIT = _G.USE_JIT
end

local cfg_name = 'config.lor'
local cfg_file = 'conf/' .. cfg_name .. '.lua'

-- NOTE hsq pwd 默认在 unit 启动时的路径，
--      配置中的 working_directory 可覆盖，并作用于静态资源。
local pwd = os.getenv('PWD')
local env = pwd:match('^(.+)/[^/]+$')

local ver = _VERSION:match('^Lua (.+)$')

package.cpath = table.concat({
    -- Sys, Nginx-Unit, Auxiliary module, ...
    env .. '/lib/'..ver..'/?.so',
    package.cpath,
}, ';')
package.path = table.concat({
    -- Lor App
    pwd .. '/app/?.lua',
    pwd .. '/?.lua',
    -- Lor Framework
    env .. '/lor/?.lua',
    -- Sys, Nginx-Unit, Auxiliary module, ...
    env .. '/lib/?.lua',
    -- env .. '/lib/'..ver..'/?.lua',
    package.path,
}, ';')

local config = {}

config.app = {
    DEBUG  = DEBUG,
    -- NOTE hsq nginx/openresty 命令的 -p 选项设定的值
    prefix = pwd,
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

config.host = {
    -- TODO hsq 支持环境变量 LOR_ENV=env ？
    -- TODO hsq 端口号来自 lib.lor.bin.scaffold.nginx.config ，生成 web 和运行都是。
    listeners = { ['*:8888'] = { pass = 'routes/lor', },},
    applications = {
        lor = {
            type              = 'external',
            processes         = 2,
            working_directory = pwd,

            -- executable        = 'app/main.lua',
            -- arguments         = {'@' .. cfg_file},

            executable = USE_JIT and '/usr/local/bin/luajit' or
                                    '/usr/local/bin/lua',
            arguments  = { 'app/main.lua', '@' .. cfg_file },},},
    routes = {
        lor = {
            {   match  = { uri = {'*.ico'} },
                action = { share = 'app/static$uri', },},
            {   match  = { uri = '~^/.*$', }, -- '~^/(hello)?$'
                action = { pass = 'applications/lor', },},
        },},}

_G.unit_config = config
return config