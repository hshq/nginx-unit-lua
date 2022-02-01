local APP_ROOT = Registry['APP_ROOT']
local Appconf={}
Appconf.sysconf = {
    'v_resource',
    'cache'
}
Appconf.page_cache = {}
Appconf.page_cache.cache_on = true
-- Appconf.page_cache.cache_handle = 'lru'
Appconf.page_cache.no_cache_cookie = 'va-no-cache'
Appconf.page_cache.no_cache_uris = {
    'uris'
}
Appconf.page_cache.build_cache_key_without_args = {'rd'}
-- TODO hsq 这里原是生成的字符串字面量
Appconf.vanilla_root = ngx.var.VANILLA_ROOT
Appconf.vanilla_version = '0_1_0_rc7'
Appconf.name = 'vanilla_demo'

Appconf.route='vanilla.v.routes.simple'
Appconf.bootstrap='application.bootstrap'

Appconf.app={}
Appconf.app.root=APP_ROOT

Appconf.controller={}
Appconf.controller.path=Appconf.app.root .. '/application/controllers/'

Appconf.view={}
Appconf.view.path=Appconf.app.root .. '/application/views/'
Appconf.view.suffix='.html'
Appconf.view.auto_render=true

return Appconf
