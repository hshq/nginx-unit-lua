#!/usr/bin/env lua5.4

local CFG_FILE = 'conf/config.lor.json'
local CFG_LUA = 'conf/config.lor.lua'

-- TODO hsq 共享 app/main.lua 中的配置处理代码
-- TODO hsq 生成 Makefile ，依赖 config.lor.lua 和 本文件？
local config = assert(loadfile(CFG_LUA))()

local unit = require 'lnginx-unit'
local cjson = require 'cjson'

-- local SOCK = unit.DEFAULT_CONFIG.CONTROL_SOCK:gsub('.-:', '')
local SOCK = unit.DEFAULT_CONFIG.CONTROL_SOCK:match('^.-:?([^:]+)$')
local HOST, PORT = next(config.unit.listeners):match('(.+):(.+)')
HOST = HOST == '*' and 'localhost' or HOST

local join = table.concat

local prettify = (require 'simple_prettify_json_encode'){
    val = config.unit,
    COMPACT = 2,
}
config = cjson.encode(config.unit)
-- NOTE hsq unit 收到配置字串会自动过滤
config = config:gsub('\\/', '/')

-- local CFG = `./$(CFG_LUA) -j -u`

-- TODO hsq 重复定义
local function sh(cmd)
    print(cmd)
    local f = assert(io.popen(cmd, 'r'))
    local r = assert(f:read('*a'))
    print(r)
    f:close()
    -- return r
end

local funcs = {}

function funcs.help()
    print 'ARG: \trestart, start, stop, save, config, get'
    print('CONF-FILE:', CFG_LUA)
    print('HOST:', HOST..':'..PORT)
    print('SOCK:', SOCK)
    print('STATE:', unit.DEFAULT_CONFIG.STATE)
    print('UNIT-CONF:')
    sh('cat '..unit.DEFAULT_CONFIG.STATE..'/conf.json')
    -- print('CONFIG:', config)
    print('CONFIG:',    prettify)
end

function funcs.start()
    sh('unitd')
end

function funcs.stop()
    sh('pkill unitd')
end

function funcs.restart()
    funcs.stop()
    funcs.start()
end

function funcs.save()
    local f = assert(io.open(CFG_FILE, 'w'))
    assert(f:write(prettify))
    assert(f:close())
end

function funcs.config()
    local cmd = join({
        'curl -s -X PUT \\',
        '   --data-binary \'%s\' \\',
        '   --unix-socket %s \\',
        '   http://%s:%s/config/',
    }, '\n')
    config = '@' .. CFG_FILE
    cmd = cmd:format(config, SOCK, HOST, PORT)
    sh(cmd)
end

function funcs.get()
    sh(('curl -s "http://%s:%s/"'):format(HOST, PORT))
end

local func = ... or 'help'
funcs[func]()