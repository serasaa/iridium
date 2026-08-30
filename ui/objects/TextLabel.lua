local UIObject =require("ui.objects.UIObject")
local Color3=require("types.Color3")
local log=require("modules.log")

---@class TextLabel : UIObject
local TextLabel = setmetatable({}, { __index = UIObject })
TextLabel.__index = TextLabel

---creates an ui text label
---@param x number
---@param y number
---@param w number
---@param h number
---@param text string?
---@param font love.font?
---@return TextLabel
function TextLabel.new(x, y, w, h, text, font,fontSize)
    local self = UIObject.new(x,y,w,h)
    setmetatable(self,TextLabel)

    self.name="TextLabel"
    self.text=text or "text"
    self.fontSize=fontSize or 14
    self.font=getFont(font,self.fontSize)
    self.font=font or love.graphics.getFont()
    self.color=Color3.new(200,200,200)
    self.alpha=1

    self.textColor=Color3.new(0,0,0)
    self.textAlpha=1
    self.textAlignmentX="center"
    self.textAlignmentY="center"
    self.autoClip=true
    self.autoTextPos=true

    return self
end

function TextLabel:draw(onEditor)
    ---@type Color3
    local backColor=self.color
    ---@type Color3
    local textColor=self.textColor

    local font=getFont(self.font,self.fontSize)

    local absX, absY = self:getAbsolutePosition()
    local roundness=self.cornerRadius*uiMan.Scale
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
    local lineCount = 1

    local txtAlgnX=self.textAlignmentX
    local txtAlgnY=self.textAlignmentY
    
    if textWidth>self.w and self.autoTextPos then
        if txtAlgnX=="left" then
            txtAlgnX="right"
        elseif txtAlgnX=="right" then
            txtAlgnX="left"
        end
    end
    
    for _ in self.text:gmatch("\n") do
        lineCount = lineCount + 1
    end

    local textHeight = font:getHeight() * lineCount

    local textPosX = absX
    local textPosY = absY

    if txtAlgnX=="center" then
        textPosX = absX + (self.w - textWidth) / 2
    elseif txtAlgnX=="right" then
        textPosX = absX + self.w - textWidth
    end

    if txtAlgnY=="center" then
       textPosY = absY + (self.h - textHeight) / 2
    elseif txtAlgnY=="bottom" then
       textPosY = absY + self.h - textHeight
    end

    local sx,sy,sw,sh=love.graphics.getScissor()
    
    if sx and isRectInside({x=absX,y=absY,w=self.w,h=self.h},{x=sx,y=sy,w=sw,h=sh}) then
        love.graphics.setScissor(absX,absY,self.w,self.h)
    elseif not sx then
        love.graphics.setScissor(absX,absY,self.w,self.h)
    end
    if onEditor or self.autoClip==false then love.graphics.setScissor() end
    love.graphics.print(
        self.text,
        textPosX,
        textPosY,
        0, 1, 1, 0, 0
    )
    love.graphics.setScissor(sx,sy,sw,sh)
    table.sort(self.children,function (a, b)
        return a.zIndex<b.zIndex
    end)

    for i,v in ipairs(self.children) do
        v:draw(onEditor)
    end

    love.graphics.pop()
end

function TextLabel:update(dt)
    for i,v in pairs(self.children) do
        v:update(dt)
    end
end

return TextLabel