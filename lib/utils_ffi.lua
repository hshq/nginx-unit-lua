
local ffi = require 'ffi'
local C = ffi.C


ffi.cdef[[
    typedef int pid_t;
    pid_t getpid(void);
    pid_t getppid(void);
]]

local function getpid()
    return C.getpid()
end

local function getppid()
    return C.getppid()
end

return {
    getpid  = getpid,
    getppid = getppid,
}