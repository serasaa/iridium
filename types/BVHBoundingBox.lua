---@class bvhBoundBox
local bvhBoundBox={}
bvhBoundBox.__index=bvhBoundBox

function bvhBoundBox.new()
    local self = setmetatable({}, bvhBoundBox)

    self.points={}
    
    self.minBounds = {math.huge, math.huge, math.huge}
    self.maxBounds = {-math.huge, -math.huge, -math.huge}
    
    return self
end

function bvhBoundBox:expandBounds(v)
    self.minBounds[1] = math.min(self.minBounds[1], v[1])
    self.minBounds[2] = math.min(self.minBounds[2], v[2])
    self.minBounds[3] = math.min(self.minBounds[3], v[3])

    self.maxBounds[1] = math.max(self.maxBounds[1], v[1])
    self.maxBounds[2] = math.max(self.maxBounds[2], v[2])
    self.maxBounds[3] = math.max(self.maxBounds[3], v[3])
end

return bvhBoundBox