---@class Color3
---@field R number
---@field G number
---@field B number
local Color3={}
Color3.__index=Color3


---comment
---@param r number
---@param g number
---@param b number
---@return Color3
function Color3.new(r,g,b)
    local self = setmetatable({},Color3)

    self.R=r/255
    self.G=g/255
    self.B=b/255
    
    return self
end

---@return Color3
function Color3:toRGB()
    return Color3.new(
        self.R * 255,
        self.G * 255,
        self.B * 255
    )
end

return Color3