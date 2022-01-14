#!/usr/bin/env lua5.4

local USE_JIT = true

local cfg_name = 'config.lor'
local cfg_file = 'conf/' .. cfg_name .. '.lua'

-- NOTE hsq pwd 默认在 unit 启动时的路径，
--      配置中的 working_directory 可覆盖，并作用于静态资源。
local pwd = os.getenv('PWD')
local env = pwd:match('^(.+)/[^/]+$')

local ver = _VERSION:match('^Lua (.+)$')

package.cpath = table.concat({
    env .. '/lib/'..ver..'/?.so',
    package.cpath,
}, ';')
package.path =  table.concat({
    pwd .. './app/?.lua',
    pwd .. './?.lua',
    env .. '/lor/?.lua',
    env .. '/lib/'..ver..'/?.lua',
    env .. '/lib/?.lua',
    package.path,
}, ';')

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
            processes         = 2,
            working_directory = pwd,

            -- executable        = 'app/main.lua',
            -- arguments         = {'@' .. cfg_file},

            executable        = USE_JIT and '/usr/local/bin/luajit' or
                                            '/usr/local/bin/lua',
            arguments         = {'app/main.lua', '@' .. cfg_file},
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

_G.unit_config = config
return config