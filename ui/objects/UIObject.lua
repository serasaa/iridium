local log=require("modules.log")

---@class UIObject
local UIObject={}
UIObject.__index=UIObject

---this is a super type. not meant to be used
---@param x number
---@param y number
---@param w number
---@param h number
---@return UIObject
function UIObject.new(x, y, w, h)
    local self = setmetatable({}, UIObject)

    self.x = x or 0
    self.y = y or 0
    self.w = w or 64
    self.h = h or 64
    self.rotation=0
    self.cornerRadius=0
    self.anchorX="left"
    self.anchorY="top"

    self.visible = true
    self.zIndex = 1
    self.children={}
    self.parent=nil

    return self
end

--- Recursively climbs the parent tree to find the true screen position
---@return number, number
function UIObject:getAbsolutePosition()
    local parentX, parentY = 0, 0
    if self.parent then
        if type(self.parent.getAbsolutePosition) == "function" then
            parentX, parentY = self.parent:getAbsolutePosition()
        else
            parentX, parentY = self.parent.x or 0, self.parent.y or 0
        end

        if self.parent.positionY then
            parentY = parentY + math.floor(self.parent.positionY)
        end
    end
    return (self.x or 0) + parentX, (self.y or 0) + parentY
end

function UIObject:draw(onEditor)
  
end

function UIObject:update(dt)
    if self.children then
        for _, child in ipairs(self.children) do
            child:update(dt)
        end
    end
end

return UIObject