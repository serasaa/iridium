local json = require("modules.json")

local Frame = require("ui.objects.Frame")
local TextButton = require("ui.objects.TextButton")
local TextLabel = require("ui.objects.TextLabel")
local TextInput = require("ui.objects.TextInput")
local ImageButton = require("ui.objects.ImageButton")
local UIImage = require("ui.objects.UIImage")
local ScrollingFrame = require("ui.objects.ScrollingFrame")

local exporter = {}

local CLASS_BY_PROTOTYPE = {
    [Frame] = "Frame",
    [TextButton] = "TextButton",
    [TextLabel] = "TextLabel",
    [TextInput] = "TextInput",
    [ImageButton] = "ImageButton",
    [UIImage] = "ImageLabel",
    [ScrollingFrame] = "ScrollingFrame",
}

local HANDLED_KEYS = {
    class = true,
    position = true,
    size = true,
    color = true,
    imageColor=true,
    zIndex = true,
    name = true,
    alpha = true,
    visible = true,
    anchorX = true,
    anchorY = true,
    text = true,
    font = true,
    fontSize = true,
    textColor = true,
    textAlpha = true,
    textAlignmentX = true,
    textAlignmentY = true,
    image = true,
    canvasHeight = true,
    children = true,
}

local SKIP_KEYS = {
    x = true,
    y = true,
    w = true,
    h = true,
    parent = true,
    children = true,
    class = true,
    isPressed = true,
    isHovered = true,
    isFocused = true,
    lastHover = true,
    shadowDirty = true,
    shadowCanvas = true,
    blurCanvas = true,
    velocity = true,
    positionY = true,
    targetDelta = true,
    frictionValue = true,
    minPos = true,
    maxPos = true,
    cursorVisible = true,
    cursorTimer = true,
}

local function isColor3(value)
    return type(value) == "table" and value.R ~= nil and value.G ~= nil and value.B ~= nil
end

local function colorToArray(color)
    if not color then
        return nil
    end
    if isColor3(color) then
        return { color.R * 255, color.G * 255, color.B * 255 }
    end

    return {
        color.r or color[1] or 255,
        color.g or color[2] or 255,
        color.b or color[3] or 255,
    }
end

local function resolveClass(node)
    local className = node.class

    if not className then
        local mt = getmetatable(node)
        if mt and mt.__index then
            className = CLASS_BY_PROTOTYPE[mt.__index]
        end
    end

    className = className or "Frame"

    if className == "UIImage" then
        className = "ImageLabel"
    end

    return className
end

local function unscale(value, scale)
    if value == nil then
        return nil
    end
    return value / scale
end

function exporter.serializeNode(node, scale)
    scale = scale or 1

    local data = {}
    data.class = resolveClass(node)
    data.position = { unscale(node.x or 0, scale), unscale(node.y or 0, scale) }
    data.size = { unscale(node.w or 0, scale), unscale(node.h or 0, scale) }

    if node.color then
        data.color = colorToArray(node.color)
    end
    if node.imageColor then
        data.imageColor=colorToArray(node.imageColor)
    end

    data.zIndex = node.zIndex or 1
    data.name = node.name or "UIObject"
    data.alpha = node.alpha or 1
    data.visible = node.visible ~= false
    data.anchorX = node.anchorX
    data.anchorY = node.anchorY

    if node.text ~= nil then
        data.text = node.text
        data.font = node.font
        if node.fontSize then
            data.fontSize = unscale(node.fontSize, scale)
        end
        if node.textColor then
            data.textColor = colorToArray(node.textColor)
        end
        data.textAlpha = node.textAlpha or 1
        data.textAlignmentX = node.textAlignmentX
        data.textAlignmentY = node.textAlignmentY
    end

    if node.image then
        data.image = node.image
        data.imageAlpha=node.imageAlpha or 1
    end

    if data.class == "ScrollingFrame" and node.canvasHeight then
        data.canvasHeight = unscale(node.canvasHeight, scale)
    end

    for key, value in pairs(node) do
        if not SKIP_KEYS[key]
            and not HANDLED_KEYS[key]
            and type(value) ~= "function"
            and type(value) ~= "table"
        then
            data[key] = value
        elseif isColor3(value) and not HANDLED_KEYS[key] and not SKIP_KEYS[key] then
            data[key] = colorToArray(value)
        end
    end
    data.children = {}
    for _, child in ipairs(node.children or {}) do
        table.insert(data.children, exporter.serializeNode(child, scale))
    end

    return data
end

function exporter.toTable(objectList, scale)
    local output = {}

    for _, object in ipairs(objectList or {}) do
        table.insert(output, exporter.serializeNode(object, scale))
    end

    return output
end

function exporter.fromUIManager(uiMan, editorRequest)
    local objectList = uiMan.Objects
    if editorRequest == true then
        objectList = uiMan.editorObjects
    end

    return exporter.toTable(objectList, uiMan.Scale or 1)
end

function exporter.encode(uiMan, editorRequest)
    return json.encode(exporter.fromUIManager(uiMan, editorRequest))
end

local function writeFile(filePath, content)

    local file, err = io.open(filePath, "w")
    if not file then
        return false, err
    end

    file:write(content)
    file:close()
    return true
end

function exporter.write(filePath, uiMan, editorRequest)
    local content = exporter.encode(uiMan, editorRequest)
    local ok, err = writeFile(filePath, content)

    if not ok then
        error("exporter.write failed: " .. tostring(err))
    end

    return true
end

return exporter
