local base = require 'utils.base'

local exportable = exportable

local clone = base.clone
local pairs, type, assert = _G 'pairs, type, assert'


local _ENV = {}


local _M = exportable {
    DEFAULT_ROOT         = 'html',

    -- 为避免 DOS 攻击
    -- NOTE hsq 所影响的若干方法，同一方法若以不同数量限制调用，结果不同，实没必要，
    --      尽量只调用一次，或者使用同样的限制。
    MAX_ARGS             = 100,

    -- 子请求嵌套上限
    HTTP_MAX_SUBREQUESTS = 50,

    MIN_SHARED_DICT      = '8k',

    set_vars = {},

    shared_dict = {},

    prefix = function() return '' end,
}


local function init(cfg)
    local new_M = {}
    for k, v0 in pairs(_M) do
        new_M[k] = v0
        local v = cfg.ngx[k]
        if v ~= nil then
            assert(type(v) == type(v0))
            new_M[k] = v
        end
    end

    if cfg.app.set_vars then
        new_M.set_vars = clone(cfg.app.set_vars)
    end
    if cfg.app.shared_dict then
        new_M.shared_dict = clone(cfg.app.shared_dict)
    end

    local prefix = cfg.app.prefix
    if type(prefix) == 'string' then
        new_M.prefix = function() return prefix end
    end

    assert(new_M.MAX_ARGS >= 0)
    assert(new_M.HTTP_MAX_SUBREQUESTS >= 0)

    return new_M
end

return init