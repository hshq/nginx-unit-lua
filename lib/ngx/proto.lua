-- 无状态函数原型
local utils        = require 'utils'
local ngx_const    = require 'ngx.const'
local ngx_shared   = require 'ngx.shared'

local type  = type
local join  = utils.join
local merge = utils.merge

local NGX_LOG_LEVEL = ngx_const.NGX_LOG_LEVEL
local logs          = ngx_const.logs
local null          = ngx_const.null


local _M = {
    -- TODO hsq 模块导出接口能放在文件头部更好？
    decode_base64 = utils.decode_base64,
    encode_base64 = utils.encode_base64,
    md5           = utils.md5,
    md5_bin       = utils.md5_bin,
    crc32         = utils.crc32,
    crc32_short   = utils.crc32,
    crc32_long    = utils.crc32,

    escape_header_k  = utils.escape_header_k,
    escape_header_v  = utils.escape_header_v,
    escape_uri       = utils.escape_uri,
    unescape_uri     = utils.unescape_uri,
    normalize_header = utils.normalize_header,
    flatten_header   = utils.flatten_header,
    encode_args      = utils.encode_args,

    shared = ngx_shared.shared,
}

merge(_M, ngx_const.ngx_const)
merge(_M, (require 'ngx.datetime'))
merge(_M, (require 'ngx.todo'))


function _M.get_phase()
    -- NOTE hsq 只支持 content ？ unit 不区分 phase ？
    return 'content'
end

-- NOTE hsq 建议代码风格： return ngx.exit(...)
--  代码片段：反馈自定内容的错误页
--      ngx.status = ngx.HTTP_GONE -- 410 Gone
--      ngx.say("This is our own content")
--      ngx.exit(ngx.HTTP_OK)
function _M.exit(status)
    if status == ngx.OK then -- 退出当前 phase ，进入后续。
        status = ngx.HTTP_OK
    elseif status == ngx.ERROR then
        status = ngx.HTTP_INTERNAL_SERVER_ERROR
    end
    assert(type(status) == 'number' and status >= ngx.HTTP_OK)
    -- TODO hsq ngx.exit 能否不用 error 来退出并传递信息？
    -- NOTE hsq 字符串/数字 会被前缀文件、代码行等位置信息。
    return error({status = status}, 2) -- 中断请求， status 传给 ngx 。
end


function _M.log(level, ...)
    local name = NGX_LOG_LEVEL[level]
    local args = {...}
    for i, arg in ipairs(args) do
        args[i] = arg == null and 'null' or tostring(arg)
    end
    -- NOTE hsq join 得到的字串中可能含有 % 字符，若置于 fmt 参数位置会报错（缺少参数）。
    logs[level]('%s', join(args))
end


return _M