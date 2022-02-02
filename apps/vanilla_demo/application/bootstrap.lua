local simple = LoadV 'vanilla.v.routes.simple'
local restful = LoadV 'vanilla.v.routes.restful'

local Bootstrap = Class('application.bootstrap')

function Bootstrap:initWaf()
    LoadV('vanilla.sys.waf.acc'):check()
end

function Bootstrap:initErrorHandle()
    self.dispatcher:setErrorHandler({controller = 'error', action = 'error'})
end

function Bootstrap:initRoute()
    local router = self.dispatcher:getRouter()
    local simple_route = simple:new(self.dispatcher:getRequest())
    local restful_route = restful:new(self.dispatcher:getRequest())
    router:addRoute(restful_route, true)
    router:addRoute(simple_route)
    -- print_r(router:getRoutes())
end

function Bootstrap:initView()
end

function Bootstrap:initPlugin()
    local admin_plugin = LoadPlugin('admin'):new()
    self.dispatcher:registerPlugin(admin_plugin);
end

function Bootstrap:boot_list()
    return {
        -- Bootstrap.initWaf,
        -- Bootstrap.initErrorHandle,
        -- Bootstrap.initRoute,
        -- Bootstrap.initView,
        -- Bootstrap.initPlugin,
    }
end

function Bootstrap:__construct(dispatcher)
    self.dispatcher = dispatcher
end

return Bootstrap
