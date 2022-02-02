local join    = table.concat
local push    = table.insert

local ipairs  = ipairs
local assert  = assert
local package = package
local getenv  = os.getenv

local ver = _VERSION:match('^Lua (.+)$')

-- TODO hsq 加入局部变量限制代码；以及其他文件。
local _ENV = {} -- setfenv(1, {})


local unit_dir      = getenv('PWD')
local config_dir    = unit_dir .. '/config'
local framework_dir = unit_dir .. '/frameworks'
local app_dir       = unit_dir .. '/apps'

local self = config_dir .. '/config.lua'


local function dirname(path)
    return path:match('^(.+)/[^/]+$')
end

local function executable(use_jit)
    return use_jit and '/usr/local/bin/luajit' or '/usr/local/bin/lua'
end


local cfg = {
    unit = {
        dir = unit_dir,
        -- entry = 'unitd.lua',
        entry = unit_dir .. '/unitd.lua',
        config = {
            file = self,
            dir  = dirname(self),
        },
        lib   = unit_dir .. '/lib',
        path  = {
            -- NOTE hsq 在进入 web 代码前已经设置了。
            -- '{{UNIT}}/?.lua',
            '{{PATH}}',
            -- NOTE hsq 模块名中带文件路径时也可用；但路径中带'.'则出错。
            '?.lua',
        },
        cpath = {
            -- '{{UNIT}}/{{LUA-VER}}/?.so',
            '{{CPATH}}',
        },
    },
    frameworks = {
        lor     = {
            lib = framework_dir .. '/lor',
            path = { '{{FRAMEWORK}}/?.lua' },
            app_path = {
                '{{APP}}/app/?.lua',
                '{{APP}}/?.lua',
            },
        },
        vanilla = {
            lib = framework_dir .. '/vanilla/framework',
            path = { '{{FRAMEWORK}}/?.lua' },
            app_path = {
                '{{APP}}/?.lua',
                '{{APP}}/?/init.lua',
            },
        },
    },
    apps = {
        {
            name        = 'demo_1',
            framework   = 'lor',
            dir         = app_dir .. '/lor_demo',
            -- use_jit     = false,
            -- debug       = true,
        },
        {
            name        = 'demo_1',
            framework   = 'vanilla',
            dir         = app_dir .. '/vanilla_demo',
            -- use_jit     = true,
            -- debug       = true,
        },
    }
}

local function PP(vec, paths)
    paths = paths or {}
    if vec then
        for _, p in ipairs(vec) do
            push(paths, p)
        end
    end
    return paths
end

local vars = {
    -- ['{{APP}}'] = app.dir,
    -- ['{{FRAMEWORK}}'] = fw.lib,
    ['{{UNIT}}'] = cfg.unit.lib,
    ['{{LUA-VER}}'] = ver,
    ['{{PATH}}'] = package.path,
    ['{{CPATH}}'] = package.cpath,
}

-- cfg.prepare = function()
    -- TODO hsq 表内可引用自身字段会更方便（前向和后向）。
    for _, app in ipairs(cfg.apps) do
        local fw = cfg.frameworks[app.framework]
        -- fw.name  = app.framework

        local app_name = app.framework .. '.' .. app.name
        cfg.apps[app_name] = assert(not cfg.apps[app_name] and app) -- 检查命名冲突

        app.name        = app_name
        app.config_file = ('%s/%s.lua'):format(config_dir, app.name)
        app.vhost_file  = ('%s/%s.json'):format(config_dir, app.name)
        app.executable  = executable
        app.entry       = ('%s/%s.lua'):format(framework_dir, app.framework)

        app.framework   = fw
        app.unit        = cfg.unit

        app.path  = PP(cfg.unit.path, PP(fw.path, PP(fw.app_path)))
        app.cpath = PP(cfg.unit.cpath, PP(fw.cpath, PP(fw.app_cpath)))
        vars['{{APP}}']       = app.dir
        vars['{{FRAMEWORK}}'] = fw.lib
        app.path  = join(app.path, ';'):gsub('{{[^}]*}}', vars)
        app.cpath = join(app.cpath, ';'):gsub('{{[^}]*}}', vars)
    end
-- end

return cfg