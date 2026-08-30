local UIObject =require("ui.objects.UIObject")
local Color3=require("types.Color3")
local log=require("modules.log")

---@class TextButton : UIObject
local TextButton = setmetatable({}, { __index = UIObject })
TextButton.__index = TextButton

---creates an ui button
---@param x number
---@param y number
---@param w number
---@param h number
---@param onClick function?
---@param text string?
---@param font string?
---@return TextButton
function TextButton.new(x, y, w, h, text, onClick, font, fontSize)
    local self = UIObject.new(x,y,w,h)
    setmetatable(self,TextButton)

    self.name="Button"
    self.text=text or "button"
    self.fontSize=fontSize or 14
    self.font=font
    self.color=Color3.new(200,200,200)
    self.alpha=1
    self.textColor=Color3.new(0,0,0)
    self.textAlpha=1
    self.textAlignmentX="center"
    self.textAlignmentY="center"

    self.onClick=onClick
    self.isPressed=false
    self.isHovered=false

    return self
end

function TextButton:draw(onEditor)
    ---@type Color3
    local backColor=self.color
    ---@type Color3
    local textColor=self.textColor
    local font=getFont(self.font,self.fontSize) or love.graphics.newFont()
    local roundness=self.cornerRadius*uiMan.Scale
    local absX, absY = self:getAbsolutePosition()

    local ctX,ctY=absX+((self.w)/2),absY+((self.h)/2)
    love.graphics.push()
    love.graphics.translate(ctX,ctY)
    love.graphics.rotate(math.rad(self.rotation))
    love.graphics.translate(-ctX,-ctY)


    love.graphics.setColor(backColor.R,backColor.G,backColor.B,self.alpha)
    love.graphics.rectangle("fill", absX, absY, self.w, self.h,roundness,roundness)

    love.graphics.setColor(textColor.R,textColor.G,textColor.B,self.textAlpha)
    love.graphics.setFont(font)

    local textWidth = font:getWidth(self.text)
    local textHeight = font:getHeight()

    local textPosX = absX
    local textPosY = absY

    if self.textAlignmentX=="center" then
        textPosX = absX + (self.w - textWidth) / 2
    elseif self.textAlignmentX=="right" then
        textPosX = absX + self.w - textWidth 
    end

    if self.textAlignmentY=="center" then
       textPosY = absY + (self.h - textHeight) / 2
    elseif self.textAlignmentY=="bottom" then
       textPosY = absY + self.h - textHeight
    end
    
    love.graphics.print(
        self.text,
        textPosX,
        textPosY,
        0, 1, 1, 0, 0
    )
    
    table.sort(self.children,function (a, b)
        return a.zIndex<b.zIndex
    end)

    for i,v in ipairs(self.children) do
        v:draw(onEditor)
    end
    love.graphics.pop()
end

function TextButton:update(dt)
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

return TextButton