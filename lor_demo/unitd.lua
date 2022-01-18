#!/usr/bin/env lua5.4

package.path =  table.concat({
    -- '../lib/'..ver..'/?.lua',
    '../lib/?.lua',
    package.path,
}, ';')

local base = require 'utils.base'
local sh = base.sh
local join = base.join
local write_file = base.write_file

local CFG_FILE = 'conf/config.lor.json'
local CFG_LUA = 'conf/config.lor.lua'

-- TODO hsq 共享 app/main.lua 中的配置处理代码
-- TODO hsq 生成 Makefile ，依赖 config.lor.lua 和 本文件？
-- TODO hsq 制作全局 start/stop/restart 或类似命令，调用当前目录中的对应功能？
local config = assert(loadfile(CFG_LUA))()

local unit = require 'lnginx-unit'
local cjson = require 'cjson'

-- local SOCK = unit.DEFAULT_CONFIG.CONTROL_SOCK:gsub('.-:', '')
local SOCK = unit.DEFAULT_CONFIG.CONTROL_SOCK:match('^.-:?([^:]+)$')
local HOST, PORT = next(config.unit.listeners):match('(.+):(.+)')
HOST = HOST == '*' and 'localhost' or HOST


local prettify = (require 'simple_prettify_json_encode'){
    val = config.unit,
    COMPACT = 2,
}
config = cjson.encode(config.unit)
-- NOTE hsq unit 收到配置字串会自动过滤
config = config:gsub('\\/', '/')

-- local CFG = `./$(CFG_LUA) -j -u`

local function echo_sh(cmd)
    print(cmd)
    local r = sh(cmd)
    print(r)
end

local funcs = {}

function funcs.help()
    print 'ARG: \trestart, start, stop, save, config, get'
    print('CONF-FILE:', CFG_LUA)
    print('HOST:', HOST..':'..PORT)
    print('SOCK:', SOCK)
    print('STATE:', unit.DEFAULT_CONFIG.STATE)
    print('UNIT-CONF:')
    echo_sh('cat '..unit.DEFAULT_CONFIG.STATE..'/conf.json')
    -- print('CONFIG:', config)
    print('CONFIG:',    prettify)
end

function funcs.start()
    echo_sh('unitd')
end

function funcs.stop()
    echo_sh('pkill unitd')
end

function funcs.restart()
    funcs.stop()
    funcs.start()
end

function funcs.save()
    write_file(CFG_FILE, prettify)
end

function funcs.config()
    funcs.save()
    local cmd = join({
        'curl -s -X PUT \\',
        '   --data-binary \'%s\' \\',
        '   --unix-socket %s \\',
        '   http://%s:%s/config/',
    }, '\n')
    config = '@' .. CFG_FILE
    cmd = cmd:format(config, SOCK, HOST, PORT)
    echo_sh(cmd)
end

function funcs.get()
    echo_sh(('curl -s "http://%s:%s/"'):format(HOST, PORT))
end

local func = ... or 'help'
funcs[func]()