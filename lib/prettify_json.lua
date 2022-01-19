-- 0-否
-- 1-只闭括号
-- 2-压缩单项表；对象数组首个字段和 '{' 同一行
local COMPACT = 0
local INDENT  = 4
local PADDING = ' '


local base = require 'utils.base'
local push = base.push
local pop  = base.pop
local join = base.join

local type   = type
local next   = next
local pairs  = pairs
local ipairs = ipairs
local assert = assert
local fmt    = string.format


return function(task)
    -- NOTE hsq boolean 类型不能这样处理
    local COMPACT = task.COMPACT  or COMPACT
    local INDENT  = task.INDENT  or INDENT
    -- local PADDING = task.PADDING or PADDING

    local val     = assert(task.val)
    local level   = 0
    local pad_str = ''
    local buf     = {}

    local function indent(dir)
        if dir == '->' then
            level = level + 1
        elseif dir == '<-' then
            level = level - 1
        end
        pad_str = PADDING:rep(level * INDENT)
    end

    local function padding(yes)
        if yes ~= false then push(buf, pad_str) end
    end

    local function line_feed(yes)
        if yes then push(buf, '\n') end
    end

    local function add(v)
        push(buf, v)
    end

    local function q(v)
        push(buf, fmt('%q', v))
    end

    local function upto1(val)
        if COMPACT<2 then return false end
        if type(val) ~= 'table' then return true end
        local k, v = next(val)
        return not k or (not next(val, k) and upto1(v))
    end

    local function format1(val)
        if type(val) == 'table' then
            local k, v = next(val)
            if k == 1 then
                add'[ '; format1(v); add' ]'
            else
                assert(type(k) == 'string', 'Field name must be a string')
                add'{ '; q(k); add': '; format1(v) ;add' }'
            end
        else
            q(val)
        end
    end

    local function format(val, vec1_is_obj)
        local typ = type(val)
        if typ == 'table' then
            if upto1(val) then format1(val); return end
            local cnt = #val
            if cnt == 0 then -- hash
                add'{\n'
                indent('->')
                cnt = #buf
                for k, v in pairs(val) do
                    assert(type(k) == 'string', 'Field name must be a string')
                    if vec1_is_obj then
                        vec1_is_obj = false
                        pop(buf); add'{'; add(PADDING:rep(INDENT-1))
                        --[[     ]]q(k); add': '; format(v); add',\n'
                    else
                        padding(); q(k); add': '; format(v); add',\n'
                    end
                end
                if #buf > cnt then
                    pop(buf); line_feed(COMPACT==0)
                end
                indent('<-')
                padding(COMPACT==0); add'}'
            else -- vector
                add'[\n'
                indent('->')
                for i, v in ipairs(val) do
                    local vec1_is_obj = i==1 and COMPACT>1
                    padding(); format(v, vec1_is_obj); add',\n'
                end
                if cnt > 0 then
                    pop(buf); line_feed(COMPACT==0)
                end
                indent('<-')
                padding(COMPACT==0); add']'
                assert(not next(val, cnt), 'Arrays and hash tables cannot be mixed')
            end
        else
            q(val)
        end
    end

    format(task.val)
    return join(buf)
end