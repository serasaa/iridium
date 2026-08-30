local math={}
function math.Clamp(val, lower, upper)
    assert(val and lower and upper, "not very useful error message here")
    if lower > upper then lower, upper = upper, lower end 
    return math.max(lower, math.min(upper, val))
end

return math