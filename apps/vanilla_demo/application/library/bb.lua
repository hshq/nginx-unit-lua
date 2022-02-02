local LibBb = Class("bb")

function LibBb:idevzDo(params)
    local params = params or { lib_bb = 'idevzDo LibBb'}
    return params
end

function LibBb:__construct( data )
    print_r('===============init bbb=========')
    self.lib = 'LibBb---------------xxx' .. data.info
    -- self.a = 'ppp'
end

function LibBb:idevzDobb(params)
    local params = params or { lib_bb = 'idevzDo idevzDobb'}
    return params
end

return LibBb
