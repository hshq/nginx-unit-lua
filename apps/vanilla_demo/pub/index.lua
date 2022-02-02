init_vanilla()
page_cache()
--+--------------------------------------------------------------------------------+--


-- if Registry['VA_ENV'] == nil then
    local helpers = LoadV "vanilla.v.libs.utils"
    function sprint_r( ... )
        return helpers.sprint_r(...)
    end

    function lprint_r( ... )
        local rs = sprint_r(...)
        print(rs)
    end

    function print_r( ... )
        local rs = sprint_r(...)
        ngx.say(rs)
    end

    function err_log(msg)
        ngx.log(ngx.ERR, "===zjdebug" .. msg .. "===")
    end
-- end
--+--------------------------------------------------------------------------------+--


Registry['VANILLA_APPLICATION']:new(ngx, Registry['APP_CONF']):bootstrap(Registry['APP_BOOTS']):run()
