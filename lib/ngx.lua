local unit  = require 'lnginx-unit'
local cjson = require 'cjson'
local utils = require 'utils'

local type       = type
-- local os_time    = os.time
local os_date    = os.date
local pairs      = pairs
local ipairs     = ipairs
local tonumber   = tonumber
local tostring   = tostring
local floor      = math.floor
local tointeger  = math.tointeger or function(num)
    local int = floor(num)
    return int == num and int or nil
end
local upper      = string.upper
local char       = string.char
local log_err    = unit.err
-- local clear      = utils.clear
local map        = utils.map
local push       = utils.push
local pop        = utils.pop
local join       = utils.join
local parseQuery = utils.parseQuery
local getpid     = utils.getpid
-- local getpid     = unit.getpid
local decode_base64 = utils.decode_base64
local encode_base64 = utils.encode_base64

local null = cjson.null


local DEFAULT_ROOT = 'html'

-- NOTE hsq strftime
-- NOTE hsq https://developer.mozilla.org/zh-CN/docs/Web/HTTP/Headers/Last-Modified
local LAST_MODIFIED_FMT = '!%a, %d %b %Y %T GMT'

local MAX_ARGS = 100

local NGX_LOG_LEVEL = { [0] = 'STDERR',
    'EMERG', 'ALERT', 'CRIT', 'ERR', 'WARN', 'NOTICE', 'INFO', 'DEBUG',
}

-- NOTE 转义字符范围，从 openresty 响应头实验中汇集。
local escape_charset = {
    [0] = '21,23-27,2A,2B,2D,2E,30-39,41-5A,5E-7A,7C,7E',   -- 都不转
    [1] = '9,20,22,28-29,2C,2F,3A-40,5B-5D,7B,7D,80-FF',    -- 只 K 转
    [2] = '0-8,A-1F,7F',                                    -- KV 都转
    K   = '0-20,22,28-29,2C,2F,3A-40,5B-5D,7B,7D,7F-FF',    -- K 转
    V   = '0-8,A-1F,7F',                                    -- V 转
}
local escape_charset_v = {}
local function char2escape(charset)
    local c2e = {}
    charset:gsub('[^,]+', function(set)
        local s, e = set:match('(%w+)%-?(%w*)')
        s = tonumber(s, 16)
        e = (e and e ~= '') and tonumber(e, 16) or s
        for b = s, e do
            c2e[char(b)] = ('%%%02X'):format(b)
        end
    end)
    return c2e
end
local char2escape_k = char2escape(escape_charset.K)
local char2escape_v = char2escape(escape_charset.V)

local ngx_proto = {}

local logs = {}
for level, name in pairs(NGX_LOG_LEVEL) do
    ngx_proto[name] = level
    logs[level] = unit[name:lower()] or unit.alert
end

ngx_proto.null = null

ngx_proto.log = function(level, ...)
    local name = NGX_LOG_LEVEL[level]
    local args = {...}
    for i, arg in ipairs(args) do
        args[i] = arg == null and 'null' or tostring(arg)
    end
    -- NOTE hsq join 得到的字串中可能含有 % 字符，若置于 fmt 参数位置会报错（缺少参数）。
    logs[level]('%s', join(args))
end

ngx_proto.time = os.time
ngx_proto.http_time = function(ts)
    return os_date(LAST_MODIFIED_FMT, ts)
end

ngx_proto.decode_base64 = decode_base64
ngx_proto.encode_base64 = encode_base64

ngx_proto.get_phase = function()
    -- NOTE hsq 只支持 content ？ unit 不区分 phase ？
    return 'content'
end

ngx_proto.location = {}
-- TODO hsq ngx_proto.location.capture(uri options?)
ngx_proto.location.capture = function(uri, options)
end

-- TODO hsq ngx 需要拆分为基础部分和框架部分？
-- TODO hsq 可根据 cfg 初始化一次，反复使用，而非每个请求都调用？是否有效果？
local function make_ngx(cfg, req)
    local ngx = {
        config = {
            prefix = function() return cfg.prefix end,
        },
    }

    for k, v in pairs(ngx_proto) do
        ngx[k] = v
    end

    -- 临时用 resolved_vars
    -- local resolved_vars = {
    -- }
    -- http://nginx.org/en/docs/http/ngx_http_core_module.html#variables
    local sys_vars = { -- 必须先定义。有字段，也可有数组部分。
        server_protocol = req.version,
        server_name     = req.server_name,
        remote_addr     = req.remote,
        document_root   = cfg.prefix .. '/' .. DEFAULT_ROOT,
        uri             = req.path,
        request_uri     = req.target,
        query_string    = req.query,
        args            = req.query,
        pid             = getpid(),
        }
    local user_vars = {}
    local uri_args, uri_args_msg = nil, nil
    local post_args, post_args_msg = nil, nil
    local function set_user_var(k, v)
        if type(v) ~= 'string' then
            unit.alert('set_user_var(%s, %s) 值参数(#2) 必须是字符串。', k, type(v))
        elseif sys_vars[k] then
            unit.alert('variable "%s" not changeable', k)
        else
            user_vars[k] = v
            return true
        end
    end
    for k, v in pairs(cfg.set_vars) do
        set_user_var(k, v)
    end
    ngx.var = setmetatable({}, {
        __index = function (t, k)
            local v = sys_vars[k] or user_vars[k]
            if v then return v end
            -- ngx.var.arg_VAR
            local n = k:match('^arg_([%w_]+)$')
            if n then
                if not uri_args then
                    uri_args = ngx.req.get_uri_args(MAX_ARGS)
                end
                v = uri_args[n]
                if v then return v end
            end
            -- NOTE hsq ngx.var.HEADER: $http_HEADER 全小写、连接线变成下划线。
            local h = k:match('^http_([a-z_0-9]+)$')
            if h then
                h = req.field_refs[h]
                return h and req.fields[h] or nil
            end
            -- if resolved_vars[k] then
            --     return nil
            -- end
            return log_err('未定义变量 <ngx.var.%s>', k)
        end,
        __newindex = function (t, k, v)
            if k == 'args' then
                sys_vars.args         = v
                sys_vars.query_string = v
                -- clear(uri_args)
                uri_args = nil
            -- elseif k == 'limit_rate' then
            elseif not set_user_var(k, v) then
                unit.alert('variable "%s" does not exist', k)
            end
        end,
    })

    ngx.req = {}
    ngx.req.get_method = function()
        return req.method
    end
    ngx.req.get_headers = function()
        return req.fields
    end
    local function get_XX_args(max_args, XX_args, args_str)
        if XX_args then
            return XX_args
        end
        max_args = tointeger(max_args or MAX_ARGS)
        if not max_args then
            return nil, 'invalid max_args'
        end
        local msg = nil
        if max_args > 0 then
            XX_args = parseQuery(args_str, max_args + 1)
            if #XX_args > max_args then
                pop(XX_args)
                msg = 'truncated'
            end
        else
            XX_args = parseQuery(args_str)
        end
        return XX_args
    end
    ngx.req.get_uri_args = function(max_args)
        uri_args, uri_args_msg = get_XX_args(max_args, uri_args, sys_vars.args)
        return uri_args, uri_args_msg
    end
    ngx.req.get_post_args = function(max_args)
        if req.method ~= 'POST' then
            return nil, 'invalid METHOD: ' .. req.method
        end
        post_args, post_args_msg = get_XX_args(max_args, post_args, req.preread_content)
        return post_args, post_args_msg
    end
    ngx.req.read_body = function() end
    ngx.req.get_body_data = function() return req.preread_content end

    local function normalize_header(name)
        return name:lower():gsub('_', '-'):gsub('%f[%w]%w', upper)
    end
    local function flatten_header(name)
        return name:lower():gsub('-', '_')
    end
    local function escape_k(k)
        return k:gsub('.', char2escape_k)
    end
    local function escape_v(v)
        return v:gsub('.', char2escape_v)
    end

    -- 响应头
    local resp_headers = {}
    ngx.header = setmetatable({}, {
        __index = function (t, k)
            k = normalize_header(tostring(k))
            k = escape_k(k)
            return resp_headers[k]
        end,
        __newindex = function (t, k, v)
            k = normalize_header(tostring(k))
            k = escape_k(k)
            if v == nil or (type(v) == 'table' and #v == 0) then
                resp_headers[k] = nil
                return
            end
            -- NOTE hsq 调用方确保提供正确的类型，构造好再简单赋值
            -- TODO hsq 根据是否多项，在首次赋值前构造正确的类型？
            -- TODO hsq 多值可以分开传输，也可以(先各自转义再)合并(，并用逗号分隔)。
            -- local v0 = resp_headers[k]
            if type(v) == 'table' then
                map(map(v, tostring), escape_v)
            else
                v = escape_v(tostring(v))
            end
            resp_headers[k] = v
        end,
    })
    -- NOTE 返回 k/v 构成的一维向量
    ngx.get_response_headers = function()
        local vec = {}
        for k, v in pairs(resp_headers) do
            if type(v) ~= 'table' then
                push(vec, k)
                push(vec, v)
            else
                for _, v2 in ipairs(v) do
                    push(vec, k)
                    push(vec, v2)
                end
            end
        end
        setmetatable(resp_headers, {
            __newindex = function(t, k, v)
                unit.alert('响应标头已发出，不可更改。')
            end
        })
        return vec
    end

    local contents = {}
    ngx.print = function(...)
        for _, v in ipairs{...} do
            if type(v) == 'table' then
                ngx.print(v)
            else
                push(contents, tostring(v))
            end
        end
        return 1
    end
    ngx.say = function(...)
        ngx.print(...)
        ngx.print('\n')
        return 1
    end
    ngx.get_response_content = function()
        return join(contents)
    end

    local pid = getpid();
    local ppid = utils.getppid();
    ngx.worker = {}
    ngx.worker.id = function()
        local id = pid - ppid
        return id > 0 and id or id + 65536
    end
    ngx.worker.pid = function()
        return pid
    end

    return setmetatable(ngx, {
        __index = function (t, k)
            log_err('未实现 <ngx.%s>', k)
            return nil
        end,
    })
end

return make_ngx