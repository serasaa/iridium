local UIObject = require("ui.objects.UIObject")
local Frame = require("ui.objects.Frame")
local Color3 = require("types.Color3")
local log = require("modules.log")

---@class ScrollingFrame : Frame
local ScrollingFrame = setmetatable({}, { __index = Frame })
ScrollingFrame.__index = ScrollingFrame

---creates a new physics-based scrolling frame compatible with framework
---@param x number
---@param y number
---@param w number
---@param h number
---@param canvasHeight number The total virtual height of scrollable content
---@return ScrollingFrame
function ScrollingFrame.new(x, y, w, h, canvasHeight)
    local self = Frame.new(x, y, w, h)
    setmetatable(self, ScrollingFrame)

    self.class = "ScrollingFrame" 
    self.name = "ScrollingFrame"
    self.color = Color3.new(30, 30, 30)


    self.scrollingSensitivity = 1
    self.stiffness = 20
    self.restitution = 0.3
    self.overscrollStiffnessMultiplier = 0.8
    self.analogFrictionValue = 0.97
    self.digitalFrictionValue = 0.6
    self.impulseStrength = 30

    self.velocity = 0
    self.positionY = 0
    self.targetDelta = 0
    self.frictionValue = self.analogFrictionValue
    
    self.canvasHeight = canvasHeight or h*2
    self.autoCanvasHeight=true
    self.clipContent = true

    self.maxPos = 0 
    self.minPos = 0

    self.scrollbarVisible = true
    self.scrollbarColor = Color3.new(100, 100, 100)
    self.scrollbarWidth = 6
    self.scrollbarAlpha = 0.7

    return self
end

local function clamp(low, n, high) return math.min(math.max(n, low), high) end

function ScrollingFrame:draw(onEditor)
---@type Color3
    local backColor = self.color
    
    local absX, absY = self:getAbsolutePosition()
    local roundness=self.cornerRadius*uiMan.Scale
    local ctX,ctY=absX+((self.w)/2),absY+((self.h)/2)
    love.graphics.push()
    love.graphics.translate(ctX,ctY)
    love.graphics.rotate(math.rad(self.rotation))
    love.graphics.translate(-ctX,-ctY)

    love.graphics.setColor(backColor.R,backColor.G,backColor.B,self.alpha)
    love.graphics.rectangle("fill", absX, absY, self.w, self.h,roundness)

    local sx, sy, sw, sh = love.graphics.getScissor()
    love.graphics.setScissor(absX, absY, self.w, self.h)

    table.sort(self.children,function (a, b)
        return a.zIndex < b.zIndex
    end)
    
    for i,v in ipairs(self.children) do
        v:draw(onEditor)
    end
    
    love.graphics.setScissor(sx, sy, sw, sh)

    if self.scrollbarVisible and self.canvasHeight > self.h then
        love.graphics.push("all")

        love.graphics.setColor(self.scrollbarColor.R, self.scrollbarColor.G, self.scrollbarColor.B, self.scrollbarAlpha)
        love.graphics.setLineWidth(1)

        local padding = 12
        local barX = absX + self.w - self.scrollbarWidth - padding

        local visibleRatio = self.h / self.canvasHeight
        local barSizeH = visibleRatio * self.h - padding*2

        local scrollRange = math.abs(self.minPos)
        local currentScroll = math.abs(self.positionY)
        local normalizedPos = currentScroll / scrollRange
        
        local overscrollH = 0
        if self.positionY < self.minPos then
             overscrollH = math.abs(self.positionY - self.minPos) / 2
        elseif self.positionY > self.maxPos then
             overscrollH = math.abs(self.positionY - self.maxPos) / 2
        end
        barSizeH = math.max(barSizeH - overscrollH, self.scrollbarWidth * 2)

        local barY = absY + (normalizedPos * ((self.h - barSizeH) - padding)) 

        love.graphics.rectangle("fill", barX, barY, self.scrollbarWidth, barSizeH, self.scrollbarWidth / 2)

        love.graphics.pop()
    end
    love.graphics.pop()
end

function ScrollingFrame:update(dt)
    self.minPos = math.min(0, self.h - self.canvasHeight)

    if self.autoCanvasHeight then
        local totalSize=0
        for i,v in pairs(self.children) do
            totalSize=totalSize+v.x+v.h
        end
        self.canvasHeight=totalSize
    end

    local overscroll = 0
    if self.positionY < self.minPos then
        overscroll = self.positionY - self.minPos
    elseif self.positionY > self.maxPos then
        overscroll = self.positionY - self.maxPos
    end

    self.velocity = self.velocity * self.frictionValue
    self.velocity = self.velocity + (self.targetDelta * self.impulseStrength)
    self.positionY = self.positionY + self.velocity

    if overscroll ~= 0 then
        self.frictionValue = self.analogFrictionValue

        local overscrollScale = math.abs(overscroll) / self.h 

        local dynamicStiffness = self.stiffness * ((1 + overscrollScale) * self.overscrollStiffnessMultiplier)
        local springForce = -overscroll * dynamicStiffness

        self.velocity = self.velocity + (springForce * dt)
        self.velocity = self.velocity * self.restitution
    end

    self.targetDelta = 0
    
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

function ScrollingFrame:handleMouseWheel(wheelDeltaY)
    if not self.isHovered then return end

    local finalDelta = wheelDeltaY * self.scrollingSensitivity

    if math.floor(wheelDeltaY) == wheelDeltaY then
        self.frictionValue = self.digitalFrictionValue
    else
        finalDelta=wheelDeltaY*.05
        self.frictionValue = self.analogFrictionValue
    end

    self.targetDelta = self.targetDelta + finalDelta
end

return ScrollingFrame