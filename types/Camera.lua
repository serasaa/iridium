---@class Camera
local Camera={}
Camera.__index=Camera

local worldUp = {0, -1, 0}

function Camera:rebuildBasis()
    self.forward = normalize(self.forward)

    self.right = normalize(cross(self.forward, worldUp))
    self.up = cross(self.right, self.forward)
    print(self.forward)
end

function Camera.new()
    local self = setmetatable({}, Camera)

    self.pos={0, 0, 0}
    self.rot={0, 0, 0}
    self.forward={0,0,1}
    self.right={1,0,0}
    self.up={0,-1,0}
    self.fov=math.rad(70)

    self:rebuildBasis()

    return self
end

function Camera:rotateYaw(angle)

    self.forward = normalize(rotateVectorAroundAxis(self.forward, worldUp, angle))
    self.right = normalize(cross(self.forward, worldUp))
    self.up = cross(self.right, self.forward)
end

function Camera:rotatePitch(angle)
    self.forward = normalize(rotateVectorAroundAxis(self.forward, self.right, angle))
    self.up = normalize(cross(self.right, self.forward))
end

function Camera:getRayDir(x, y)
    local scale = math.tan(self.fov * 0.5)

    local px = x * scale
    local py = y * scale

    return normalize({
        self.forward[1] + self.right[1] * px + self.up[1] * py,
        self.forward[2] + self.right[2] * px + self.up[2] * py,
        self.forward[3] + self.right[3] * px + self.up[3] * py,
    })
end


return Camera