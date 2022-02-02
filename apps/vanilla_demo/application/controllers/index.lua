-- local IndexController = Class('controllers.index', LoadApplication('controllers.base'))
-- local IndexController = Class('controllers.index')
local IndexController = {}
local user_service = LoadApplication('models.service.user')
local aa = LoadLibrary('aa')

-- function IndexController:__construct()
-- -- self.parent:__construct()
--     print_r('===============IndexController:init===============')
-- -- --     -- self.aa = aa({info='ppppp'})
-- -- --     -- self.parent:__construct()
--     local get = self:getRequest():getParams()
--     self.d = '===============index===============' .. get.act
-- end

function IndexController:index()
  return 'hello vanilla.'
end

function IndexController:indext()
    -- self.parent:fff()
    -- do return user_service:get() 
    --           .. sprint_r(aa:idevzDobb()) 
    --           .. sprint_r(Registry['v_sysconf']['db.client.read']['port']) 
    --           -- .. sprint_r(self.aa:idevzDobb()) 
    --           -- .. sprint_r(self.parent.aaa) 
    --           .. Registry['APP_NAME']
    --           -- .. self.d
    -- end
    local view = self:getView()
    local p = {}
    p['vanilla'] = 'Welcome To Vanilla...' .. user_service:get()
    p['zhoujing'] = 'Power by Openresty'
    view:assign(p)
    return view:display()
end

function IndexController:buested()
  return 'hello buested.'
end

-- curl http://localhost:9110/get?ok=yes
function IndexController:get()
    local get = self:getRequest():getParams()
    print_r(get)
    do return 'get' end
end

-- curl -X POST http://localhost:9110/post -d '{"ok"="yes"}'
function IndexController:post()
    local _, post = self:getRequest():getParams()
    print_r(post)
    do return 'post' end
end

-- curl -H 'accept: application/vnd.YOUR_APP_NAME.v1.json' http://localhost:9110/api?ok=yes
function IndexController:api_get()
    local api_get = self:getRequest():getParams()
    print_r(api_get)
    do return 'api_get' end
end

return IndexController
