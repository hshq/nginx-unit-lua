#!/usr/bin/env lua5.4

local pwd     = os.getenv('PWD')
local lib_dir = pwd .. '/lib'
local cfg_dir = pwd .. '/config'

local ver = _VERSION:match('^Lua (.+)$')

local func, target_app = ...
func = func or 'info'


local require        = require
local package        = package
local assert         = assert
local ipairs         = ipairs
local pairs          = pairs
local dofile         = dofile
local print          = print
local type           = type
local next           = next
local tonumber       = tonumber
local tointeger      = math.tointeger
local select         = select
local collectgarbage = collectgarbage
local getenv         = os.getenv
local echo           = io.write
local join           = table.concat
local unpack         = table.unpack
local _G             = _G


-- NOTE hsq 只在 Lua5.4 限制并充分测试即可
-- setfenv(1, {})
local _ENV = {}


-- TODO hsq 共享模块加载路径，至少是基础模块。
-- NOTE hsq 相对路径易出问题。
package.path = join({
    lib_dir .. '/?.lua',
    cfg_dir .. '/?.lua',
    package.path,
}, ';')
package.cpath = join({
    -- Sys, Nginx-Unit, Auxiliary module, ...
    lib_dir .. '/'..ver..'/?.so',
    package.cpath,
}, ';')


local config = require 'config'

local utils   = require 'utils'
local unit    = require 'lnginx-unit'
local cjson   = require 'cjson'
local inspect = require 'inspect'

local jdec = cjson.decode
-- local jenc = cjson.encode

-- TODO hsq 用法还是繁琐；而且不方便注释掉；
-- TODO hsq 只在入口处导入 utils.base 。
local sh, is_jit, write_file, setcwd, pjson =
    utils 'sh, is_jit, write_file, setcwd, pjson'


local app_configs = {}

-- gsub('.-:', '')
local SOCK = unit.DEFAULT_CONFIG.CONTROL_SOCK:match('^.-:?([^:]+)$')

local function pjson_encode(obj)
    return pjson {
        val     = obj,
        COMPACT = 2,
    }
end

-- config.prepare()

for i, app in ipairs(config.apps) do
    -- _G.USE_JIT = is_jit
    -- _G.USE_JIT = app.use_jit
    _G.app = app
    -- TODO hsq 配置文件中也有加载路径处理，重复了；或者将其作为模块来加载？
    -- local config_data = assert(loadfile(assert(app.config_file)))()
    local config_data = assert(dofile(assert(app.config_file)))
    _G.app = nil
    -- local config_data = `./$(app.config_file) -j -u`

    if app.framework.name == 'vanilla' then
        assert((config_data.vhost.applications[app.name].processes or 1) < 2,
            'TODO hsq ngx.shared 模拟实现不支持多进程')
    end

    app.host, app.port = next(config_data.vhost.listeners):match('(.+):(.+)')
    app.host = (app.host == '*') and 'localhost' or app.host

    -- local config_str = jenc(config_data.vhost)
    -- -- NOTE hsq unit 收到配置字串会自动过滤
    -- config_str = config_str:gsub('\\/', '/')

    app_configs[app.name] = config_data

    if target_app == app.name or tonumber(target_app) == i then
        target_app = app
    end
end
assert(not target_app or type(target_app) == 'table', 'Invalid APP-NAME or APP-NO.')

local function echo_sh(cmd)
    print(cmd)
    print(sh(cmd))
end

local funcs = {}
local fks = {
    -- 1:名, 2:App参数
    {'info',    0},
    {'restart',0},
    {'start',   0},
    {'quit',    0},
    {'vhost',   1},
    {'detail',  1},
    {'update',  1},
    {'get',     2},
}

local function list_apps()
    print('apps:')
    for i, app in ipairs(config.apps) do
        print('', i, app.name)
    end
end

function funcs.info()
    print 'funcs:'
    for _, c in ipairs(fks) do
        local n, a = unpack(c)
        local s, r = n:match('^(.)(.+)$')
        local p = 'APP-NAME/No.'
        echo(('\t\27[04m\27[01m%s\27[0m%s'):format(s, r))
        print((a == 1 and ('\t[%s]'):format(p)) or
            (a == 2 and ('\t<%s>'):format(p)) or '')
    end
    print ''
    list_apps()
end

function funcs.detail(app)
    if app then
        local cfg = app_configs[app.name]
        print('env:',   inspect(app))
        print('app:',   inspect(cfg.app))
        print('ngx:',   inspect(cfg.ngx))
        print('vhost:', pjson_encode(cfg.vhost))
    else
        print(inspect(config))
        list_apps()
    end
end

-- web 入口；其他方法是 shell 管理。
function funcs.run(app)
    assert(getenv('NXT_UNIT_INIT'), 'Not executable in shell')
    -- assert(app)
    if not app then
        list_apps()
        return
    end
    -- funcs.detail(app)

    package.path  = app.path
    package.cpath = app.cpath
    -- assert(setcwd(app.dir))

    collectgarbage('collect')
    collectgarbage('collect')

    _G.unit_config = app_configs[app.name]

    local entry = assert(app.entry) -- assert(app.framework.entry)
    -- assert(loadfile(entry))()
    dofile(entry)

    _G.unit_config = nil
end

local function get_vhost(echo)
    local cmd = ([[curl -s --unix-socket '%s' URL]]):format(SOCK)
    if echo then
        print(cmd)
    end
    local r = sh(cmd)
    return (r and r ~= '') and jdec(r) or nil
end

function funcs.vhost(app)
    -- echo_sh('cat '..unit.DEFAULT_CONFIG.STATE..'/conf.json')

    local function prune(vhost, node)
        if not vhost[node] then return end
        for k, v in pairs(vhost[node]) do
            if k ~= app.name or (node == 'listeners' and not v.pass:find(app.name)) then
                vhost[node][k] = nil
            end
        end
    end

    local vhost = get_vhost(true)
    if not vhost then
        print ''
        return
    end
    -- TODO hsq JSON 解码后是浮点数
    for _, v in pairs((vhost.config or vhost).applications) do
        v.processes = tointeger(v.processes)
    end
    if app then
        -- print(inspect(app))
        vhost = vhost.config or vhost
        -- print(inspect(vhost))
        prune(vhost, 'listeners')
        prune(vhost, 'routes')
        prune(vhost, 'applications')
        -- print(inspect(vhost))
        print(pjson_encode(vhost))
    else
        -- print(inspect(vhost))
        print(pjson_encode(vhost))

        list_apps()
    end
end

function funcs.start()      echo_sh('unitd') end
function funcs.quit()       echo_sh('pkill unitd') end
function funcs.restart()    funcs.quit() funcs.start() end

local empty_vhost = {applications={},routes={['']={}},listeners={}}

function funcs.update(app)
    local function update_part(vhost, node)
        local cmd = [[curl -s -XPUT --data-binary '%s' --unix-socket '%s' \
            URL/config/%s/%s]]
        local key, value = next(vhost[node])
        cmd = cmd:format(pjson_encode(value), SOCK, node, key)
        -- echo_sh(cmd)
        print(cmd)
        local r = sh(cmd)
        return assert(jdec(r).success and r, r)
    end

    local function update(vhost, filepath, overwrite)
        write_file(filepath, pjson_encode(vhost))
        if overwrite then
            local cmd = [[curl -s -X PUT --data-binary '%s' --unix-socket '%s' \
                URL/config/]]
            cmd = cmd:format('@' .. filepath, SOCK)
            echo_sh(cmd)
        else
            local vhost0 = get_vhost()
            vhost0 = vhost0 and (vhost0.config or vhost0)
            if not vhost0 then
                return update(vhost, filepath, true)
            end
            -- NOTE hsq 缺省没有 routes 节点： {"certificates": {},
            --      "config": {"applications": {}, "listeners": {}}}
            if not vhost0.routes then
                update_part(empty_vhost, 'routes')
            end
            -- NOTE hsq 更新顺序根据依赖关系
            -- NOTE hsq applications 重启 App 及其 Prototype 进程，routes/listeners 不会
            local r
            r = update_part(vhost, 'applications')
            r = update_part(vhost, 'routes')
            r = update_part(vhost, 'listeners')
            print(r)
        end
    end

    if app then
        update(app_configs[app.name].vhost, app.vhost_file, false)
    else
        local vhost = {}
        for _, a in ipairs(config.apps) do
            for gk, gv in pairs(app_configs[a.name].vhost) do
                local gvs = vhost[gk]
                if not gvs then
                    gvs = {}
                    vhost[gk] = gvs
                end
                for k, v in pairs(gv) do
                    gvs[k] = v
                end
            end
        end
        update(vhost, cfg_dir .. '/config.json', true)
    end
end

function funcs.get(app)
    assert(app)
    local path = '?desc=基于 Nginx/Unit 的 Lua 框架#'
    -- local cmd = 'curl -s -H"cookie: a=b" "http://%s:%s/%s"'
    local cmd = 'curl -s -b"a=b" "http://%s:%s/%s"'
    echo_sh(cmd:format(app.host, app.port, path))
end

for _, c in ipairs(fks) do
    funcs[c[1]:sub(1, 1)] = funcs[c[1]]
end


assert(funcs[func], 'Invalid function')(target_app, select(3, ...))