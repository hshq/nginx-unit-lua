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

local libs = {
    'lbase64',
    'lnginx-unit',
}

local mk = {
    all = {},
    clean = {},
}

for _, t in ipairs(libs) do
    lib.gen(t, inc_file)
    push(mk.all, '$(MAKE) -C ' .. t)
    push(mk.clean, '$(MAKE) -C ' .. t .. ' clean')
end
push(mk.clean, 'rm -f ' .. lib.MK_FILE)

local mk2 = {}
for t, ops in pairs(mk) do
    push(mk2, t .. ':')
    for _, op in ipairs(ops) do
        push(mk2, '\t' .. op)
    end
    push(mk2, '')
end

base.write_file(lib.MK_FILE, base.join(mk2, '\n'))