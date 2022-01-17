#!/usr/bin/env lua5.4

local BASE64_ROOT = '../deps/base64-master'

(dofile '../make.lua').gen {
    LIB_NAME = 'lbase64',
    DEP_OBJS = {BASE64_ROOT..'/lib/libbase64.o'},
    O_FILES  = {'lib-base64.o'},
    INC_DIRS = {BASE64_ROOT..'/lib',
                BASE64_ROOT..'/include'},
}