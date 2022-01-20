local unit      = require 'lnginx-unit'
local utils     = require 'utils'
local ngx_const = require 'ngx.const'
local ngx_proto = require 'ngx.proto'

local require      = require
local setmetatable = setmetatable
local type         = type
local pairs        = pairs
local ipairs       = ipairs
local tostring     = tostring
local tointeger    = math.tointeger

local log_err = unit.err

local cap_mtds_id2name    = ngx_const.cap_mtds_id2name
local http_status_id2name = ngx_const.http_status_id2name
local escape_k            = ngx_proto.escape_k
local escape_v            = ngx_proto.escape_v
local normalize_header    = ngx_proto.normalize_header
local encode_args         = ngx_proto.encode_args

local push       = utils.push
local pop        = utils.pop
local join       = utils.join
-- local clear      = utils.clear
local map        = utils.map
local clone      = utils.clone
local merge      = utils.merge
local readonly   = utils.readonly
local parseQuery = utils.parseQuery
local getpid     = utils.getpid
-- local getpid     = unit.getpid


local DEFAULT_ROOT = 'html'

local MAX_ARGS = 100

local NGX_HTTP_MAX_SUBREQUESTS = 50 -- 子请求嵌套上限


-- TODO hsq 可根据 cfg 初始化一次，反复使用，而非每个请求都调用？是否有效果？
--      需要注意隔离请求私有数据，如 ngx_req
-- @link_num int|nil 请求链的节点数
local function make_ngx(cfg, req, link_num)
    link_num = (link_num or 0) + 1
    if link_num > NGX_HTTP_MAX_SUBREQUESTS then
        unit.err('subrequests cycle while processing "%s"', req.path)
        return error('request was aborted', 2)
    end

    local ngx = {
        config = {
            prefix = function() return cfg.prefix end,
        },
    }

    merge(ngx, ngx_const.ngx_const)
    merge(ngx, (require 'ngx.proto'))


    -- TODO hsq 内部状态集中管理？或者按照功能拆分成子模块？
    local status
    local resp_sent = false

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
        __index = function(t, k)
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
        __newindex = function(t, k, v)
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


    -- 0-未处理，1-已读，2-已丢弃
    local body_status = 0

    local ngx_req = {}
    ngx.req = ngx_req

    -- capture exec 都是内部请求
    -- TODO hsq unit 如何实现 internal 指令？有必要？
    ngx_req.is_internal = function()
        return link_num > 1
    end
    ngx_req.get_method = function()
        return req.method
    end
    ngx_req.get_headers = function()
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
    ngx_req.get_uri_args = function(max_args)
        uri_args, uri_args_msg = get_XX_args(max_args, uri_args, sys_vars.args)
        return uri_args, uri_args_msg
    end
    -- 同步非阻塞，然后才可 get_body_data get_post_args 等
    ngx_req.read_body = function()
        if body_status > 0 then
            return body_status, false
        end
        -- TODO hsq 连接错误等可调用 error() 或以 500 结束请求处理？
        body_status = 1
        return 1, true
    end
    ngx_req.discard_body = function()
        if body_status > 0 then
            return body_status, false
        end
        -- TODO hsq 同步非阻塞，读取数据并丢弃
        body_status = 2
        return 2, true
    end
    -- openresty: 比 ngx.var.request_body 高效，因少一次内存分配和拷贝。
    ngx_req.get_body_data = function()
        if body_status == 0 or req.content_length == 0 then
            -- TODO hsq 或者已经读入文件中
            return nil
        end
        return req.preread_content
    end
    ngx_req.get_post_args = function(max_args)
        if req.method ~= 'POST' then
            return nil, 'invalid METHOD: ' .. req.method
        end
        post_args, post_args_msg = get_XX_args(max_args, post_args, req.preread_content)
        return post_args, post_args_msg
    end


    -- 响应头
    local resp_headers = {}
    ngx.header = setmetatable({}, {
        __index = function(t, k)
            k = normalize_header(tostring(k))
            k = escape_k(k)
            return resp_headers[k]
        end,
        __newindex = function(t, k, v)
            if resp_sent then
                unit.err('attempt to set ngx.header after sending out response headers')
                return
            end
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
        -- setmetatable(resp_headers, {
        --     __newindex = function(t, k, v)
        --         unit.alert('响应标头已发出，不可更改。')
        --     end
        -- })
        return vec
    end


    local contents = {}
    ngx.print = function(...)
        -- resp_sent = true
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
        -- resp_sent = true
        ngx.print(...)
        ngx.print('\n')
        return 1
    end
    ngx.get_response_content = function()
        resp_sent = true
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


    ngx.location = {}

    -- @uri string 可带 query_string
    -- @options table 可选
    ngx.location.capture = function(uri, options)
        -- TODO hsq 同步非阻塞，C层内部，无IPC，与ngx.redirect ngx.exec(内部重定向) 不同

        if type(uri) ~= 'string' or uri == '' then
            error(('invalid URI: %s!'):format(uri), 2)
        end
        -- assert(uri:sub(1, 1) ~= '@', 'Named location is not supported')

        options = options or {}
        assert(type(options) == 'table')

        local method              = options.method or ngx.HTTP_GET
        local body                = options.body    -- nil | str
        local args                = options.args    -- nil | str | table
        local ctx                 = options.ctx     -- nil | table, 普通表，可覆盖，性能不高
        local vars                = options.vars    -- nil | table, 比 URL 参数高效
        local copy_all_vars       = not not options.copy_all_vars
        local share_all_vars      = not not options.share_all_vars  -- 慎用
        local always_forward_body = not not options.always_forward_body

        method = assert(cap_mtds_id2name[method])
        assert(body == nil or type(body) == 'string')

        local args_t = type(args)
        assert(args == nil or args_t == 'string' or args_t == 'table')
        assert(ctx  == nil or type(ctx) == 'table')
        assert(vars == nil or type(vars) == 'table')

        assert(body_status > 0, 'Need to call ngx.req.read_body() first!')
        -- ngx_req.read_body()

        -- share_all_vars 优先于 copy_all_vars
        if share_all_vars and copy_all_vars then
            copy_all_vars = false
        end

        -- body 优先于 always_forward_body
        if body and #body > 0 then
            always_forward_body = false
        elseif not always_forward_body then
            always_forward_body = (method == 'POST' or method == 'PUT')
        end
        if always_forward_body then
            -- TODO hsq ngx.req.read_body 直接转寄而非拷贝
            --      放在这里合适？
        end

        -- NOTE args 为 string 则必须是已经转义的
        -- TODO hsq args 放在这里合适？ table 不解析为 query_string 更好？
        -- uri = uri .. args
        local path, query--[[ , _fragment ]] = uri:match('^([^?#]*)%??([^#]*)(#?.*)$')
        if args then
            local query2 = (args_t == 'string') and args or encode_args(args)
            query = (query == '') and query2 or
                ((query2 == '') and query or query .. '&' .. query2)
        end
        local target = (query == '') and path or (path .. '?' .. query)

        -- TODO hsq ctx=,ngx.ctx=table: 每请求独立的上下文，与子请求也独立，
        --      普通表，可覆盖，性能不高
        --      放在这里合适？
        -- TODO hsq ngx.ctx 没意义？因 unit 没有多 phase ？

        -- local vars_real
        if share_all_vars then
            -- TODO hsq share
        elseif copy_all_vars then
            -- TODO hsq copy
        end
        -- 先处理 share/copy ，再 vars
        -- TODO hsq vars 哪些 var ？

        -- 发出子请求
        -- NOTE hsq 子请求继承了父请求的请求标头，注意子请求 proxy时可能关闭更好。
        -- TODO hsq ngx 作为全局变量，必须分离出 req 相关数据；或者开一新协程处理子请求？
        local sub_req = clone(req, 1)
        sub_req.method = method
        sub_req.path   = path
        sub_req.query  = query
        sub_req.target = target
        sub_req = readonly(sub_req)
        -- unit.debug((require 'inspect')(sub_req))

        local sub_ngx = make_ngx(cfg, sub_req, link_num)
        local old_ngx = ngx
        _G.ngx = sub_ngx

        -- TODO hsq 与 main.request_handler 比较
        local app = require('app.server')
        app:run()

        -- TODO hsq res{truncated=bool[出错时]}
        -- TODO hsq 子请求直接返回给 unit 就是 ngx.exec ？
        local res = {
            status    = sub_ngx.status,
            header    = resp_headers,   -- {xx=str/vec}
            body      = sub_ngx.get_response_content(),
            truncated = false,
        }

        _G.ngx = old_ngx
        return res
    end

    return setmetatable(ngx, {
        __index = function(t, k)
            if k == 'status' then
                return status
            elseif k == 'ctx' then
                t.ctx = {}
                return t.ctx
            end
            log_err('未实现 < ... = ngx.%s >', k)
            return nil
        end,
        __newindex = function(t, k, v)
            if k == 'status' then
                if resp_sent then
                    unit.err('attempt to set ngx.status after sending out response headers')
                else
                    assert(not v or http_status_id2name[v])
                    status = v
                end
                return
            end
            log_err('未实现 < ngx.%s = ... >', k)
        end,
    })
end

return make_ngx