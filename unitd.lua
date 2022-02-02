#!/usr/bin/env lua5.4

local pwd     = os.getenv('PWD')
local lib_dir = pwd .. '/lib'
local cfg_dir = pwd .. '/config'

local ver = _VERSION:match('^Lua (.+)$')

local func, target_app = ...
func = func or 'info'

-- TODO hsq 共享模块加载路径，至少是基础模块。
-- NOTE hsq 相对路径易出问题。
package.path = table.concat({
    lib_dir .. '/?.lua',
    cfg_dir .. '/?.lua',
    package.path,
}, ';')
package.cpath = table.concat({
    -- Sys, Nginx-Unit, Auxiliary module, ...
    lib_dir .. '/'..ver..'/?.so',
    package.cpath,
}, ';')


local config = require 'config'

local utils   = require 'utils'
local unit    = require 'lnginx-unit'
local cjson   = require 'cjson'
local pjson   = require 'prettify_json'
local inspect = require 'inspect'

-- TODO hsq 用法还是繁琐；而且不方便注释掉；
-- TODO hsq 只在入口处导入 utils.base 。
local sh, join, is_jit, write_file, setcwd =
    utils 'sh, join, is_jit, write_file, setcwd'


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
    local config_data = assert(loadfile(app.config_file))()
    _G.app = nil
    -- local config_data = `./$(app.config_file) -j -u`

    if app.framework.name == 'vanilla' then
        assert((config_data.vhost.applications[app.name].processes or 1) < 2,
            'TODO hsq ngx.shared 模拟实现不支持多进程')
    end

    app.host, app.port = next(config_data.vhost.listeners):match('(.+):(.+)')
    app.host = (app.host == '*') and 'localhost' or app.host

    -- local config_str = cjson.encode(config_data.vhost)
    -- -- NOTE hsq unit 收到配置字串会自动过滤
    -- config_str = config_str:gsub('\\/', '/')

    -- TODO hsq 生成单个 json 文件？
    config_data.vhost_p = pjson_encode(config_data.vhost)
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
local fks = {'i[nfo]',
    '\n\tr[estart]', 's[tart]', 'q[uit]',
    '\n\tstate \t\t[APP-NAME/No.]',
    '\n\td[etail] \t[APP-NAME/No.]',
    '\n\tu[pdate] \t[APP-NAME/No.]',
    '\n\tg[et]  \t\t<APP-NAME/No.>',}

local function list_apps()
    print('apps:')
    for i, app in ipairs(config.apps) do
        print('', i, app.name)
    end
end

function funcs.info()
    print('funcs:', join(fks, ', '))
    print ''
    -- print('SOCK:', SOCK)
    -- print('STATE:', unit.DEFAULT_CONFIG.STATE)
    -- print ''
    list_apps()
end
funcs.i = funcs.info

function funcs.detail(app)
    if app then
        local cfg = app_configs[app.name]
        print('env:',   inspect(app))
        print('app:',   inspect(cfg.app))
        print('ngx:',   inspect(cfg.ngx))
        print('vhost:', cfg.vhost_p)
    else
        print(inspect(config))
        list_apps()
    end
end
funcs.d = funcs.detail

-- web 入口；其他方法是 shell 管理。
function funcs.run(app)
    assert(os.getenv('NXT_UNIT_INIT'), 'Not executable in shell')
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

    local entry = app.entry -- app.framework.entry
    dofile(entry)
    -- assert(loadfile(entry, 'bt', _G))()

    _G.unit_config = nil
end

function funcs.state(app)
    -- echo_sh('cat '..unit.DEFAULT_CONFIG.STATE..'/conf.json')
    local cmd = join({
        'curl -s \\',
        '   --unix-socket %s \\',
        '   URL',
    }, '\n')
    cmd = cmd:format(SOCK)
    print(cmd)
    local r = sh(cmd)
    local cfg = cjson.decode(r)
    if app then
        -- print(inspect(app))
        cfg = cfg.config or cfg
        -- print(inspect(cfg))
        for k, v in pairs(cfg.listeners) do
            if not v.pass:find(app.name) then
                cfg.listeners[k] = nil
            end
        end
        for k, v in pairs(cfg.routes) do
            if k ~= app.name then
                cfg.routes[k] = nil
            end
        end
        for k, v in pairs(cfg.applications) do
            if k ~= app.name then
                cfg.applications[k] = nil
            end
        end
        print(pjson_encode(cfg))
    else
        print(pjson_encode(cfg))

        list_apps()
    end
end

function funcs.start()
    echo_sh('unitd')
end
funcs.s = funcs.start

function funcs.quit()
    echo_sh('pkill unitd')
end
funcs.q = funcs.quit

function funcs.restart()
    funcs.quit()
    funcs.start()
end
funcs.r = funcs.restart

-- curl -s -X PUT \
--     --unix-socket /usr/local/var/run/unit/control.sock \
--     --data-binary '{ "pass": "routes/lor" }' \
--     'http://URL/config/listeners/*:8888/'
function funcs.update(app)
    local data, filepath
    local cmd = join({
        'curl -s -X PUT \\',
        '   --data-binary \'%s\' \\',
        '   --unix-socket %s \\',
        '   http://URL/config/',
    }, '\n')
    if app then
        filepath = app.vhost_file
        write_file(filepath, app_configs[app.name].vhost_p)
        data = '@' .. filepath
        cmd = cmd:format(data, SOCK)
        -- TODO hsq 根据当前配置，选择分拆更新或整体更新。
        -- TODO hsq 或者汇总各个 App 之后，比较更新！
        print(cmd)
        print 'TODO hsq NIY'
        return
    else
        local cfgs = {}
        for _, a in ipairs(config.apps) do
            for gk, gv in pairs(app_configs[a.name].vhost) do
                local gvs = cfgs[gk]
                if not gvs then
                    gvs = {}
                    cfgs[gk] = gvs
                end
                for k, v in pairs(gv) do
                    gvs[k] = v
                end
            end
        end
        filepath = cfg_dir .. '/config.json'
        write_file(filepath, pjson_encode(cfgs))
        data = '@' .. filepath
        cmd = cmd:format(data, SOCK)
    end
    echo_sh(cmd)
end
funcs.u = funcs.update

function funcs.get(app)
    assert(app)
    local path = '?desc=基于 Nginx/Unit 的 Lua 框架#'
    -- local cmd = 'curl -s -H"cookie: a=b" "http://%s:%s/%s"'
    local cmd = 'curl -s -b"a=b" "http://%s:%s/%s"'
    echo_sh(cmd:format(app.host, app.port, path))

end
funcs.g = funcs.get


assert(funcs[func], 'Invalid function')(target_app, select(3, ...))