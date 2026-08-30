local UIObject =require("ui.objects.UIObject")
local Color3=require("types.Color3")
local log=require("modules.log")

---@class UIImage : UIObject
local UIImage = setmetatable({}, { __index = UIObject })
UIImage.__index = UIImage

---creates an ui button
---@param x number
---@param y number
---@param w number
---@param h number
---@param image string?
---@return UIImage
function UIImage.new(x, y, w, h, image)
    local self = UIObject.new(x,y,w,h)
    setmetatable(self,UIImage)

    self.name="Image"
    self.image=image or "/assets/images/logo.png"
    self.color=Color3.new(255,255,255)
    self.imageColor=Color3.new(255,255,255)
    self.imageAlpha=1
    self.alpha=1

    self.isHovered=false
    self.hoverChanged=hoverChanged

    return self
end

function UIImage:draw(onEditor)
    ---@type love.Image
    local image = getImage(self.image)
    local absX, absY = self:getAbsolutePosition()
    local iw, ih = image:getWidth(), image:getHeight()
    local color=self.color
    local imgColor=self.imageColor or Color3.new(255,255,255)
    image:setFilter("linear", "linear")

    local roundness=self.cornerRadius*uiMan.Scale
    local ctX,ctY=absX+((self.w)/2),absY+((self.h)/2)

    love.graphics.push()
    love.graphics.translate(ctX,ctY)
    love.graphics.rotate(math.rad(self.rotation))
    love.graphics.translate(-ctX,-ctY)

    love.graphics.setColor(color.R,color.G,color.B,self.alpha)
    love.graphics.rectangle("fill", absX, absY, self.w, self.h,roundness,roundness)

    if image then
        love.graphics.setColor(imgColor.R,imgColor.G,imgColor.B,self.imageAlpha)
        love.graphics.draw(image,absX,absY,0,self.w/iw,self.h/ih)
    end
    table.sort(self.children,function (a, b)
        return a.zIndex<b.zIndex
    end)

    for i,v in ipairs(self.children) do
        v:draw(onEditor)
    end
    
    love.graphics.pop()
end

local lastHover=false
function UIImage:update(dt)
    local mx, my = love.mouse.getPosition()
    local absX, absY = self:getAbsolutePosition()
    
    local hovered = mx > absX and mx < absX + self.w and my > absY and my < absY + self.h

    if hovered then self.isHovered=true else self.isHovered=false end
    
    if self.hoverChanged then
        if hovered~=lastHover then
            log.log("last hovered", hovered)
            self.hoverChanged(hovered)
        end
    end

    for i,v in pairs(self.children) do
        v:update(dt)
    end
    lastHover=hovered
end

return UIImage