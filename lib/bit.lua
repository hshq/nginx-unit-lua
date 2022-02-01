-- TODO hsq bit 库： pureffi 需要 。
return exportable {
    rshift = function(a, b) return a >> b end,
    bxor   = function(a, b) return a |  b end,
    band   = function(a, b) return a &  b end,
}