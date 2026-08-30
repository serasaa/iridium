local UIObject =require("ui.objects.UIObject")
local Color3=require("types.Color3")
local log=require("modules.log")

---@class ImageButton : UIObject
local ImageButton = setmetatable({}, { __index = UIObject })
ImageButton.__index = ImageButton

---creates an ui button
---@param x number
---@param y number
---@param w number
---@param h number
---@param onClick function?
---@param image string?
---@return ImageButton
function ImageButton.new(x, y, w, h, image, onClick)
    local self = UIObject.new(x,y,w,h)
    setmetatable(self,ImageButton)

    self.name="Image"
    self.image=image or "/assets/images/logo.png"
    self.color=Color3.new(255,255,255)
    self.alpha=1

    self.onClick=onClick
    self.isPressed=false
    self.isHovered=false

    return self
end

function ImageButton:draw(onEditor)
    ---@type love.Image
    local image = getImage(self.image)
    local absX, absY = self:getAbsolutePosition()
    local iw, ih = image:getWidth(), image:getHeight()
    local color=self.color
    local roundness=self.cornerRadius*uiMan.Scale

    local ctX,ctY=absX+((self.w)/2),absY+((self.h)/2)
    love.graphics.push()
    love.graphics.translate(ctX,ctY)
    love.graphics.rotate(math.rad(self.rotation))
    love.graphics.translate(-ctX,-ctY)

    love.graphics.setColor(color.R,color.G,color.B,self.alpha)
    love.graphics.rectangle("fill", absX, absY, self.w, self.h,roundness,roundness)

    if image then
        love.graphics.setColor(1,1,1,1)
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

function ImageButton:update(dt)
    local mx, my = love.mouse.getPosition()
    local absX, absY = self:getAbsolutePosition()
    local hovered = mx > absX and mx < absX + self.w and my > absY and my < absY + self.h

    if hovered and love.mouse.isDown(1) and self.visible==true then
        self.isPressed = true
    end 

    if hovered then self.isHovered=true else self.isHovered=false end

    if self.isPressed and not love.mouse.isDown(1) then
        if hovered and self.onClick then
            self.onClick(self,mx,my)
        end
        self.isPressed = false
    end
    for i,v in pairs(self.children) do
        v:update(dt)
    end
end

return ImageButton