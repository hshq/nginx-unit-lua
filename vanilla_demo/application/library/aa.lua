local LibAa = Class("aa", LoadLibrary('bb'))

function LibAa:idevzDo(params)
    local params = params or { lib_aa = 'idevzDo LibAa'}
    return params
end

function LibAa:__construct( data )
 print_r('===============init==aaa=======' .. data.info)
 -- self.parent:init()
 self.lib = 'LibAa----------------------------aaaa'
end

return LibAa
