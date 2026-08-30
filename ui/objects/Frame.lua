local UIObject = require("ui.objects.UIObject")
local Color3 = require("types.Color3")
local log = require("modules.log")

---@class Frame : UIObject
local Frame = setmetatable({}, { __index = UIObject })
Frame.__index = Frame


---creates an ui button
---@param x number
---@param y number
---@param w number
---@param h number
---@return Frame
function Frame.new(x, y, w, h)
    local self = UIObject.new(x, y, w, h)
    setmetatable(self, Frame)

    self.name = "Frame"
    self.color = Color3.new(200, 200, 200)
    self.alpha = 1
    self.isHovered = false
    self.hoverChanged = nil
    self.outline = false
    
    self.backgroundBlurred=false
    self.blurRadius=16
    self.shadow = false
    self.shadowRadius = 16
    self.shadowDirty = true
    self.shadowAlpha=.4

    return self
end

function Frame:bakeShadow()
    local scale = (uiMan and uiMan.Scale) or 1
    
    local baseW = self.w / scale
    local baseH = self.h / scale
    
    local radius = self.shadowRadius 
    local pad = radius * 2
    
    local sX = math.ceil(baseW + pad)
    local sY = math.ceil(baseH + pad)

    if not self.shadowCanvas or self.shadowCanvas:getWidth() ~= sX or self.shadowCanvas:getHeight() ~= sY then
        self.shadowCanvas = love.graphics.newCanvas(sX, sY)
        self.blurCanvas = love.graphics.newCanvas(sX, sY)
        
        self.shadowCanvas:setFilter("linear", "linear")
        self.blurCanvas:setFilter("linear", "linear")
    end

    love.graphics.setCanvas(self.shadowCanvas)
    love.graphics.clear(0, 0, 0, 0)
    love.graphics.setColor(0, 0, 0, 1) 
    love.graphics.rectangle("fill", pad / 2, pad / 2, baseW, baseH)

    love.graphics.setCanvas(self.blurCanvas)
    love.graphics.clear(0, 0, 0, 0)
    love.graphics.setColor(1, 1, 1, 1)
    
    love.graphics.draw(self.shadowCanvas)
    
    love.graphics.setShader()
    love.graphics.setCanvas()
    
    self.shadowDirty = false
end

function Frame:draw(onEditor)
    local absX, absY = self:getAbsolutePosition()
    if (self.shadow) and not onVita then
        
        if self.shadowDirty then 
            self:bakeShadow()
        end

        local scale = (uiMan and uiMan.Scale) or 1
        
        local screenPad = self.shadowRadius * scale * 2

        love.graphics.setColor(1, 1, 1, self.shadowAlpha)
        
        love.graphics.draw(
            self.blurCanvas, 
            absX - screenPad / 2, 
            absY - screenPad / 2, 
            0,
            scale, 
            scale
        )
    end

    local backColor = self.color
    local mode = self.outline and "line" or "fill"
    local roundness=self.cornerRadius*uiMan.Scale
    
    local ctX,ctY=absX+((self.w)/2),absY+((self.h)/2)
    love.graphics.push()
    love.graphics.translate(ctX,ctY)
    love.graphics.rotate(math.rad(self.rotation))
    love.graphics.translate(-ctX,-ctY)

        love.graphics.setColor(backColor.R, backColor.G, backColor.B, self.alpha)
        love.graphics.rectangle(mode, absX, absY, self.w, self.h,roundness,roundness)
   
    
    --love.graphics.setShader()
    table.sort(self.children, function(a, b)
        return a.zIndex < b.zIndex
    end)

    for i, v in ipairs(self.children) do
        v:draw(onEditor)
    end
    love.graphics.pop()
end

function Frame:update(dt)
    local mx, my = love.mouse.getPosition()
    local absX, absY = self:getAbsolutePosition()
    
    local hovered = mx > absX and mx < absX + self.w and my > absY and my < absY + self.h

    self.isHovered = hovered
    
    if self.hoverChanged then
        if hovered ~= self.lastHover then
            self.hoverChanged(hovered)
        end
    end

    for i, v in pairs(self.children) do
        v:update(dt)
    end
    
    self.lastHover = hovered
end

return Frame