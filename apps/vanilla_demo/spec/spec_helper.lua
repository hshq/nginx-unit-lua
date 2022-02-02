-- TODO hsq 这里原是生成的字符串字面量
local vrv = ngx.var.VANILLA_ROOT .. '/' .. ngx.var.VANILLA_VERSION
package.path = package.path .. ";/?.lua;/?/init.lua;{{VRV}/?.lua;{{VRV}/?/init.lua;;";
package.cpath = package.cpath .. ";/?.so;{{VRV}/?.so;;";
package.path = package.path:gsub('{{VRV}}', vrv)
package.cpath = package.cpath:gsub('{{VRV}}', vrv)

Registry={}
-- TODO hsq 这里原是生成的字符串字面量
Registry['APP_ROOT'] = (require 'utils').getcwd()
Registry['APP_NAME'] = 'vanilla_demo'

LoadV = function ( ... )
    return require(...)
end

LoadApp = function ( ... )
    return require(Registry['APP_ROOT'] .. '/' .. ...)
end

LoadV 'vanilla.spec.runner'
