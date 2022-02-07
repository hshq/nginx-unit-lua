
local ffi = require 'ffi'
local C      = ffi.C
local Cdef   = ffi.cdef
local Cnew   = ffi.new
local Cstr   = ffi.string
local Cerrno = ffi.errno

require 'utils.adapter'
local ERRNO = require 'utils.ffi_errno'

local tonumber  = tonumber
local tointeger = math.tointeger
local assert    = assert
local type      = type


local _ENV = {}


-- TODO hsq FFI 实现 lcodec ？
-- TODO hsq 如何直接调用 Lua API(需传入 lua_State *)，以及传出栈顶的值作为返回值？

-- TODO hsq C 声明语句单独放在 ffi.h 文件中？便于直接进入系统头文件。

-- NOTE hsq ffi.new('char *', nil) == nil ，
--      但是 strptime 出错时的结果是 cdata<char*>: 0x0 ， ~= nil 。
-- TODO hsq ffi.new('char *', nil) -->
--      LuaJIT: data<char *>: NULL
--      Lua5.4: data<char*>: 0x0
local function is_nil(cdata)
    local num = tonumber(cdata)
    return cdata == nil or num == nil or num == 0
end

Cdef [[
    // extern int errno;
    char *strerror(int errnum);
]]

local function Cerr(errno)
    -- return Cstr(C.strerror(errno or C.errno))
    -- NOTE hsq setenv('', 'will fail') 根据 man(3) 应该报错 EINVAL ，
    --      C.errno 报错 EAGAIN 。
    return Cstr(C.strerror(errno or Cerrno()))
end


Cdef [[
    typedef int pid_t;
    pid_t getpid(void);
    pid_t getppid(void);

    // char *getenv(const char *name);
    int setenv(const char *name, const char *value, int overwrite);

    // #define MAXPATHLEN 1024
    // char *getwd(char *buf);
    char *getcwd(char *buf, size_t size);
    int chdir(const char *path);
    // int fchdir(int fildes);
]]

local function getpid()
    return C.getpid()
end

local function getppid()
    return C.getppid()
end

-- @overwrite? boolean [true]
local function setenv(name, value, overwrite)
    assert(type(name)  == 'string')
    assert(type(value) == 'string')
    overwrite = overwrite ~= false
    if C.setenv(name, value, overwrite) == 0 then
        return true
    end
    return nil, Cerr()
end

local function setcwd(dir)
    assert(type(dir) == 'string')
    if C.chdir(dir) == 0 then
        return true
    end
    return nil, Cerr()
end

local function getcwd()
    local wd = C.getcwd(nil, 0)
    if not is_nil(wd) then
        return Cstr(wd)
    end
    -- local len = 256
    -- local wd = Cnew('char[?]', len)
    -- if not is_nil(C.getcwd(wd, len)) then
    --     return Cstr(wd)
    -- end
    return nil, Cerr()
end


Cdef [[
    struct tm {
        int	tm_sec;		/* seconds after the minute [0-60] */
        int	tm_min;		/* minutes after the hour [0-59] */
        int	tm_hour;	/* hours since midnight [0-23] */
        int	tm_mday;	/* day of the month [1-31] */
        int	tm_mon;		/* months since January [0-11] */
        int	tm_year;	/* years since 1900 */
        int	tm_wday;	/* days since Sunday [0-6] */
        int	tm_yday;	/* days since January 1 [0-365] */
        int	tm_isdst;	/* Daylight Savings Time flag */
        long	tm_gmtoff;	/* offset from UTC in seconds */
        char	*tm_zone;	/* timezone abbreviation */
    };
    typedef long time_t;
    char *strptime(const char *, const char *, struct tm *);
    time_t timegm(struct tm * const);
]]

local function parse_time(time, fmt)
    local tm = Cnew('struct tm')
    local ok = C.strptime(time, fmt, tm)
    return not is_nil(ok) and C.timegm(tm) or nil
end

Cdef [[
    struct timeval {
        long    tv_sec;         /* seconds */
        long    tv_usec;        /* and microseconds */
    };
    struct timezone {
        int     tz_minuteswest; /* minutes west of Greenwich */
        int     tz_dsttime;     /* type of dst correction */
    };
    int gettimeofday(struct timeval *tp, void *tzp);
]]

-- @all? boolean
local function now(all)
    local tv = Cnew('struct timeval');
    local tz, rc
    if all then
        tz = Cnew('struct timezone');
        rc = C.gettimeofday(tv, tz)
    else
        rc = C.gettimeofday(tv, nil)
    end
    if rc ~= 0 then return 0 end
    -- NOTE hsq long 是 cdata ， int 是 number
    local sec, usec = tonumber(tv.tv_sec), tonumber(tv.tv_usec)
    if all then
        return sec, usec, tz.tz_minuteswest, tz.tz_dsttime
    else
        return sec + usec / 1000000
    end
end

Cdef [[
    struct timespec {
        time_t tv_sec;	/* seconds */
        long tv_nsec;	/* nanoseconds */
    };
    unsigned int sleep(unsigned int seconds);
    int nanosleep(const struct timespec *rqtp, struct timespec *rmtp);
]]

-- return int 剩余时间
local function sleep(seconds)
    seconds = tointeger(seconds)
    assert(seconds and seconds >= 0)
    return C.sleep(seconds)
end

local function nanosleep(seconds, nanoseconds)
    seconds     = tointeger(seconds)     or 0
    nanoseconds = tointeger(nanoseconds) or 0
    assert(seconds >= 0 and nanoseconds >= 0 and nanoseconds < 1000000000
        --[[ and seconds + nanoseconds > 0 ]])

    -- local req = Cnew('struct timespec');
    -- local rest = Cnew('struct timespec');
    local tps = Cnew('struct timespec[2]');
    local req, rest = tps[1], tps[2]
    req.tv_sec, req.tv_nsec = seconds, nanoseconds
    local r = C.nanosleep(req, rest)
    if r == 0 then
        return true
    end
    local errno = Cerrno()
    if errno == ERRNO.EINTR then
        return {seconds = rest[1], nanoseconds = rest[2]}, Cerr(errno)
    else
        return nil, Cerr(errno) -- ERRNO.EINVAL
    end
end


return {
    getpid  = getpid,
    getppid = getppid,
    setenv  = setenv,
    getcwd  = getcwd,
    setcwd  = setcwd,

    parse_time = parse_time,
    now        = now,
    sleep      = sleep,
    nanosleep  = nanosleep,
}