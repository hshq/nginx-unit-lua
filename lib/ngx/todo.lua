-- TODO hsq module 'ngx.todo'
local require    = require
local exportable = exportable
local assert     = assert

local string     = string

local _G = _G


local _ENV = {}


-- return 1|nil, str_msg
local function eof()
    -- 显式指定响应输出流的结尾。在HTTP 1.1分块编码输出的情况下，它只会触发Nginx内核发送“最后一块”。
    -- 禁用 HTTP 1.1 keep-alive 特性时，此方法使得编写良好的下游客户端主动关闭连接。
    --      可用于执行后台任务时避免客户端等待。
    -- 注意上游模块是否会随着连接关闭中止子请求和主请求，要使其忽略。
    -- 做后台工作的更好方法是使用 ngx.timer.at API 。
    return true
end


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
    -- { regex = "uris", subject = <URI 不带查询串> }
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
-- { "gmatch", options = "o", regex = "/([A-Za-z0-9_]+)", subject = <URI 不带查询串> }
    local ngx = _G.ngx
    ngx.log(ngx.ERR, (require 'inspect'){
        'gmatch',
        subject = subject,
        regex = regex,
        options = options,
    })
    -- return nil, 'TODO hsq re.gmatch'
    -- return function(...) return nil end
    return string.gmatch(subject, regex)
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
    eof      = eof,
    flush    = flush,

    socket = socket,

    re = re,
}