local BaseController = Class('controllers.base')

function BaseController:__construct()
    print_r('----------------BaseController:init----------------')
    local get = self:getRequest():getParams()
    self.d = '----------------base----------------' .. get.act
end

function BaseController:fff()
    self.aaa = 'dddddd'
end

return BaseController
