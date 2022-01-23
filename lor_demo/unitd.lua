#!/usr/bin/env lua5.4

package.path = table.concat({
    '../lib/?.lua',
    package.path,
}, ';')

local base = require 'utils.base'
local sh         = base.sh
local join       = base.join
local is_jit     = base.is_jit
local write_file = base.write_file

local CFG_FILE = 'conf/config.lor.json'
-- TODO hsq 配置文件中也有加载路径处理，重复了；或者将其作为模块来加载？
local CFG_LUA  = 'conf/config.lor.lua'

-- TODO hsq 共享 app/main.lua 中的配置处理代码？
-- TODO hsq 生成 Makefile ，依赖 config.lor.lua 和 本文件？
local func = ... or 'help'
local args = {select(2, ...)}
_G.USE_JIT = is_jit
local config = assert(loadfile(CFG_LUA))()

local unit = require 'lnginx-unit'
local cjson = require 'cjson'

-- local SOCK = unit.DEFAULT_CONFIG.CONTROL_SOCK:gsub('.-:', '')
local SOCK = unit.DEFAULT_CONFIG.CONTROL_SOCK:match('^.-:?([^:]+)$')
local HOST, PORT = next(config.host.listeners):match('(.+):(.+)')
HOST = HOST == '*' and 'localhost' or HOST


local prettify = (require 'prettify_json'){
    val = config.host,
    COMPACT = 2,
}
config = cjson.encode(config.host)
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
    local path = '?desc=基于 Nginx/Unit 的 Lua 框架#'
    -- echo_sh(('curl -s -H"cookie: a=b" "http://%s:%s/%s"'):format(HOST, PORT, path))
    echo_sh(('curl -s -b"a=b" "http://%s:%s/%s"'):format(HOST, PORT, path))

end

assert(funcs[func], 'invalid func: ' .. func)(args)