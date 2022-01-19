#!/usr/bin/env lua5.4

package.path = table.concat({
    '../lib/?.lua',
    package.path,
}, ';')

local base = require 'utils.base'
local push = base.push

local lib = require 'make.lib'
-- local inc = require 'make.inc'
local inc_file = './make/inc.lua'

local ver = _VERSION:match('^Lua (.+)$')

local libs = {
    'lbase64',
    'lnginx-unit',
}

local mk_order = {'all', 'clean'}
local mk = {
    all   = { 'mkdir -p ../lib/' .. ver .. '/lnginx-unit' },
    clean = { 'rm -f ' .. lib.MK_FILE },
}

for _, t in ipairs(libs) do
    lib.gen(t, inc_file)
    push(mk.all, '$(MAKE) -C ' .. t)
    push(mk.clean, '$(MAKE) -C ' .. t .. ' clean')
end

local mk2 = {}
for _, t in ipairs(mk_order) do
    push(mk2, t .. ':')
    for _, op in ipairs(mk[t]) do
        push(mk2, '\t' .. op)
    end
    push(mk2, '')
end

base.write_file(lib.MK_FILE, base.join(mk2, '\n'))