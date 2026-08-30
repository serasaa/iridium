local BVHBoundingBox = require "types.BVHBoundingBox"
---@class bvhNode
local bvhNode={}
bvhNode.__index=bvhNode

function bvhNode.new()
    local self = setmetatable({}, bvhNode)

    --                     pA      pB      pC
    -- triangle vectors ({x,y,z},{x,y,z},{x,y,z})
    self.triangles={}
    -- them boundbox
    self.boundingBox=BVHBoundingBox.new()
    
    -- child nodes (if any)
    self.childA=nil
    self.childB=nil
    self.isLeaf=0
    
    return self
end

function bvhNode:expandBounds(v)
    self.minBounds[1] = math.min(self.minBounds[1], v[1])
    self.minBounds[2] = math.min(self.minBounds[2], v[2])
    self.minBounds[3] = math.min(self.minBounds[3], v[3])

    self.maxBounds[1] = math.max(self.maxBounds[1], v[1])
    self.maxBounds[2] = math.max(self.maxBounds[2], v[2])
    self.maxBounds[3] = math.max(self.maxBounds[3], v[3])
end

return bvhNode