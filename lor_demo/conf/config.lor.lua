#!/usr/bin/env lua5.4

local cfg_name = 'config.lor'
local cfg_file = 'conf/' .. cfg_name .. '.lua'

-- NOTE hsq pwd 默认在 unit 启动时的路径，
--      配置中的 working_directory 可覆盖，并作用于静态资源。
local pwd = os.getenv('PWD')
local env = pwd:match('^(.+)/[^/]+$')

package.cpath = table.concat({
    package.cpath,
    env .. '/lib/5.4/?.so',
}, ';')
package.path =  table.concat({
    package.path,
    pwd .. './app/?.lua',
    pwd .. './?.lua',
    env .. '/lib/5.4/?.lua',
    env .. '/lib/?.lua',
    env .. '/lor/?.lua',
}, ';')

local typ  = 'web' -- -w[web]/-u[unit]/-a[all]
local json = false -- -j
for _, arg in ipairs{...} do
    arg = arg:lower()
    if arg == '-w' then     typ = 'web'
    elseif arg == '-u' then typ = 'unit'
    elseif arg == '-a' then typ = nil
    elseif arg == '-j' then json = true
    end
end

local config = {}

config.web = {
    -- NOTE hsq nginx/openresty 命令的 -p 选项设定的值
    prefix = pwd,
    set_vars = {
        template_root = '',
    },
}

config.unit = {
    listeners = {
        ['*:8888'] = {
            pass = 'routes/lor',
        },
    },
    applications = {
        lor = {
            type              = 'external',
            executable        = 'app/unit.lua',
            working_directory = pwd,
            arguments         = {'@' .. cfg_file},
            processes         = 1,
        },
    },
    routes = {
        lor = {
            {
                match = {
                    uri = '~^/(hello)?$',
                },
                action = {
                    pass = 'applications/lor',
                },
            },
            {
                action = {
                    share = 'app/static$uri',
                },
            },
        },
    },
}

config = config[typ] or config

if json then
    local cj = require 'cjson'
    config = cj.encode(config)
    -- NOTE hsq unit 收到配置字串会自动过滤
    -- config = config:gsub('\\/', '/')
    print(config)
end

return config