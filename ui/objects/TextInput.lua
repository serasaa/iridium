local UIObject = require("ui.objects.UIObject")
local Color3 = require("types.Color3")
local log = require("modules.log")

---@class TextInput : UIObject
local TextInput = setmetatable({}, { __index = UIObject })
TextInput.__index = TextInput

---@param x number
---@param y number
---@param w number
---@param h number
---@param text string?
---@param callback function?
---@param font love.font?
---@param fontSize number?
---@return TextInput
function TextInput.new(x, y, w, h, text, callback, font, fontSize)
    local self = UIObject.new(x, y, w, h)
    setmetatable(self, TextInput)

    self.name = "TextInput"
    self.class = "TextInput"
    
    self.text = text or ""
    self.fontSize = fontSize or 14

    self.font = font or "SpaceMono-Regular"
    
    self.color = Color3.new(20, 20, 20)
    self.alpha = 1
    self.textColor = Color3.new(255, 255, 255)
    self.textAlpha = 1
    
    self.textAlignmentX = "center"
    self.textAlignmentY = "center"
    self.textOffset = 12 

    self.isFocused = false
    self.onComplete = callback 

    self.cursorVisible = true
    self.cursorTimer = 0
    self.cursorBlinkSpeed = 0.5
    self.cursorWidth = 2
    self.cursorColor = Color3.new(255, 255, 255)

    return self
end

function TextInput:draw(onEditor)
    local font = getFont(self.font, self.fontSize)
    local absX, absY = self:getAbsolutePosition()
    self.text = tostring(self.text)
    local roundness=self.cornerRadius*uiMan.Scale
    local ctX,ctY=absX+((self.w)/2),absY+((self.h)/2)
    love.graphics.push()
    love.graphics.translate(ctX,ctY)
    love.graphics.rotate(math.rad(self.rotation))
    love.graphics.translate(-ctX,-ctY)

    love.graphics.setColor(self.color.R, self.color.G, self.color.B, self.alpha)
    love.graphics.rectangle("fill", absX, absY, self.w, self.h,roundness,roundness)

    if self.isFocused then
        love.graphics.setLineWidth(uiMan.Scale)
        love.graphics.setColor(64/255, 156/255, 1)
        love.graphics.rectangle("line", absX, absY, self.w, self.h,roundness,roundness)
    end

    local sx, sy, sw, sh = love.graphics.getScissor()

    local screenX, screenY = love.graphics.transformPoint(absX, absY)

    love.graphics.intersectScissor(screenX, screenY, self.w, self.h)

    love.graphics.setColor(self.textColor.R, self.textColor.G, self.textColor.B, self.textAlpha)
    love.graphics.setFont(font)
    
    local textWidth = font:getWidth(self.text)
    local txtAlgnX="left"
    
    for _ in self.text:gmatch("\n") do
        lineCount = lineCount + 1
    end


    local textPosX = absX+self.textOffset
    local curPosX=textPosX + textWidth + 2

    if textWidth>self.w then
        txtAlgnX="right"
    end

    if txtAlgnX=="right" and self.isFocused then
        textPosX = (absX-self.textOffset)+ self.w - textWidth
    end

    love.graphics.print(self.text, textPosX, absY + (self.h - font:getHeight()) / 2)

    if self.isFocused and self.cursorVisible then
        love.graphics.setColor(self.cursorColor.R, self.cursorColor.G, self.cursorColor.B, self.textAlpha)
        love.graphics.rectangle("fill", curPosX, absY + (self.h - font:getHeight()) / 2, self.cursorWidth, font:getHeight(),roundness,roundness)
    end

    love.graphics.setScissor(sx, sy, sw, sh)
    
    for _, v in ipairs(self.children) do 
        v:draw(onEditor) 
    end
    love.graphics.pop()
end

function TextInput:update(dt)
    if self.isFocused then
        self.cursorTimer = self.cursorTimer + dt
        if self.cursorTimer >= self.cursorBlinkSpeed then
            self.cursorVisible = not self.cursorVisible
            self.cursorTimer = 0
        end
    end
end

---@param t string
function TextInput:textinput(t)
    self.text = self.text .. t
end

---@param key string
function TextInput:keypressed(key)
    if key == "backspace" then
        if #self.text > 0 then
            self.text = self.text:sub(1, -2)
        end
    elseif key == "return" or key == "kpenter" then
        if self.onComplete then
            self.onComplete(self.text)
        end
        uiMan:setFocus()
    end
end

return TextInput