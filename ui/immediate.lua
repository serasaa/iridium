---@class ui
local ui = {}

local Color3=require("types.Color3")

---comment
---@param x number
---@param y number
---@param w number
---@param h number
---@param zIndex number?
---@param text string?
---@return boolean
function ui.button(x, y, w, h, text, zIndex)
    local mx, my = love.mouse.getPosition()
    local hovered = mx > x and mx < x+w and my > y and my < y+h
    local clicked = false

    if hovered and love.mouse.isDown(1) then
        clicked = true
    end

    love.graphics.setColor(hovered and 0.8 or 0.5, 0.5, 0.5)
    love.graphics.rectangle("fill", x, y, w, h)

    if text then
        love.graphics.setColor(1, 1, 1)
        love.graphics.print(text, x+4, y+4)
    end

    return clicked
end

---comment
---@param x number
---@param y number
---@param w number
---@param h number
---@param color Color3
function ui.frame(x,y,w,h,color)
    local r,g,b=normalizedColor.R,normalizedColor.G,normalizedColor.B
    love.graphics.setColor(color)
    love.graphics.rectangle("fill",x,y,w,h)
end

function ui.debugText(text)
    love.graphics.setColor(1,1,1)
    love.graphics.print(text,12,12)
end

return ui