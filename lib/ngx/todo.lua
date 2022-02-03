-- TODO hsq module 'ngx.todo'
local require    = require
local exportable = exportable

local _G = _G


local _ENV = {}


-- TODO hsq ok, err = ngx.flush(wait?) ， 返回 1 或 nil, msg 。
--  wait? 缺省 false ，异步，立即返回、不等输出数据写入系统发送缓冲区；
--      否则同步，等待写入缓冲区或超时；同步也不会阻塞 Nginx；
--      流式输出：print()/say() 后立即 flush(true) 。
--      在 HTTP 1.0 输出缓冲模式中不起作用。
local function flush(wait)
end


local socket = {}
-- tcpsock = ngx.socket.tcp()
function socket.tcp()
    return nil, 'TODO hsq socket.tcp'
end


local re = {}
-- from, to, err = ngx.re.find(subject, regex, options?, ctx?, nth?)
function re.find(subject, regex, options, ctx, nth)
    local ngx = _G.ngx
    -- { regex = "uris", subject = "/" }
    -- { regex = "json", subject = "text/html, ..."}
    ngx.log(ngx.ERR, (require 'inspect'){
        'find',
        subject = subject,
        regex = regex,
        options = options,
        ctx = ctx,
        nth = nth,
    })
    return nil, nil, 'TODO hsq re.find'
end
-- captures, err = ngx.re.match(subject, regex, options?, ctx?, res_table?)
function re.match(subject, regex, options, ctx, res_table)
    local ngx = _G.ngx
    ngx.log(ngx.ERR, (require 'inspect'){
        'match',
        subject = subject,
        regex = regex,
        options = options,
        ctx = ctx,
        res_table = res_table,
    })
    return nil, 'TODO hsq re.match'
end
-- iterator, err = ngx.re.gmatch(subject, regex, options?)
function re.gmatch(subject, regex, options)
    local ngx = _G.ngx
    ngx.log(ngx.ERR, (require 'inspect'){
        'gmatch',
        subject = subject,
        regex = regex,
        options = options,
    })
    return nil, 'TODO hsq re.gmatch'
end
-- newstr, n, err = ngx.re.sub(subject, regex, replace, options?)
function re.sub(subject, regex, replace, options)
    local ngx = _G.ngx
    ngx.log(ngx.ERR, (require 'inspect'){
        'sub',
        subject = subject,
        regex = regex,
        replace = replace,
        options = options,
    })
    return nil, nil, 'TODO hsq re.sub'
end
-- newstr, n, err = ngx.re.gsub(subject, regex, replace, options?)
function re.gsub(subject, regex, replace, options)
    local ngx = _G.ngx
    ngx.log(ngx.ERR, (require 'inspect'){
        'gsub',
        subject = subject,
        regex = regex,
        replace = replace,
        options = options,
    })
    return nil, nil, 'TODO hsq re.gsub'
end


return exportable {
    flush = flush,

    socket = socket,

    re = re,
}