local join    = table.concat
local push    = table.insert

local ipairs  = ipairs
local assert  = assert
local package = package
local getenv  = os.getenv

local ver = _VERSION:match('^Lua (.+)$')

-- TODO hsq 加入局部变量限制代码；以及其他文件。
local _ENV = {} -- setfenv(1, {})


local unit_dir = getenv('PWD')
local self = unit_dir .. '/config/config.lua'

local config_file = 'config.lua'
local vhost_file  = 'config.json'


local function dirname(path)
    return path:match('^(.+)/[^/]+$')
end

local function executable(use_jit)
    return use_jit and '/usr/local/bin/luajit' or '/usr/local/bin/lua'
end


local cfg = {
    -- config_file = config_file,
    -- vhost_file  = vhost_file,

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
            name = 'lor',
            app_config_dir = 'conf',
            entry = 'app/main.lua',
            lib = unit_dir .. '/lor',
            path = { '{{FRAMEWORK}}/?.lua' },
            app_path = {
                '{{APP}}/app/?.lua',
                '{{APP}}/?.lua',
            },
        },
        vanilla = {
            name = 'vanilla',
            app_config_dir = 'config',
            entry = 'pub/main.lua',
            lib = unit_dir .. '/vanilla/framework',
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
            dir         = unit_dir .. '/lor_demo',
            -- use_jit     = false,
            -- debug       = true,
        },
        {
            name        = 'demo_1',
            framework   = 'vanilla',
            dir         = unit_dir .. '/vanilla_demo',
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
        local fw      = cfg.frameworks[app.framework]
        local cfg_dir = app.dir .. '/' .. fw.app_config_dir

        app.name        = app.framework .. '.' .. app.name
        app.config_file = cfg_dir .. '/' .. config_file
        app.vhost_file  = cfg_dir .. '/' .. vhost_file
        -- app.vhost_file  = ('%s/config/config.%s.json'):format(unit_dir, app.name)
        app.executable  = executable
        app.framework   = fw
        app.unit        = cfg.unit
        app.entry       = app.dir .. '/' .. fw.entry

        assert(not cfg.apps[app.name]) -- 检查命名冲突
        cfg.apps[app.name] = app

        app.path = PP(cfg.unit.path, PP(fw.path, PP(fw.app_path)))
        app.cpath = PP(cfg.unit.cpath, PP(fw.cpath, PP(fw.app_cpath)))
        vars['{{APP}}'] = app.dir
        vars['{{FRAMEWORK}}'] = fw.lib
        app.path = join(app.path, ';'):gsub('{{[^}]*}}', vars)
        app.cpath = join(app.cpath, ';'):gsub('{{[^}]*}}', vars)
    end
-- end

return cfg