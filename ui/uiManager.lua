---@class UIManager
local ui={}

local json=require("modules.json")
local log=require("modules.log")
local Frame = require("ui.objects.Frame")
local Color3= require("types.Color3")
local TextButton = require("ui.objects.TextButton")
local TextLabel  = require("ui.objects.TextLabel")
local ImageButton= require("ui.objects.ImageButton")
local UIImage    = require("ui.objects.UIImage")
local ScrollingFrame = require("ui.objects.ScrollingFrame")
local TextInput = require("ui.objects.TextInput")

ui.Scale=1
ui.listSpacing=32
local rawEditorViewSize={1280,720}
ui.editorViewportSize={1280,720}
ui.editorObjects={}
ui.allEditorObjects={}

ui.allObjects={}
ui.Objects={}
ui.focusedObject = nil
ui.mouseOverUI=false

local function getAllObjects(list,editorRequest, allObjectsTable)
    if editorRequest == true then
        getAllObjects(list,false,ui.allEditorObjects)
    end
    allObjectsTable = allObjectsTable or ui.allObjects
    list = list or ui.Objects

    ui.allObjects = {}
    local function recurse(objects)
        for _, o in ipairs(objects) do
            table.insert(ui.allObjects, o)
            if o.children and #o.children > 0 then
                recurse(o.children)
            end
        end
    end
    recurse(list)
    return allObjectsTable
end

function ui:getAllChildrenFromObject(object)
    local returnTable={}
    local function recurse(objects)
        for _, o in ipairs(objects) do
            table.insert(returnTable, o)
            if o.children and #o.children > 0 then
                recurse(o.children)
            end
        end
    end
    recurse(object)
    return returnTable
end

function ui:getTotalZIndex(object)
    local allChild=self:getAllChildrenFromObject(object)
    local totalZIndex=0

    for i,v in pairs(allChild) do
        totalZIndex=totalZIndex+v.zIndex
    end

    return totalZIndex
end

function ui.addObject(object,editorRequest)
    local objectTable=ui.Objects
    if editorRequest and editorRequest==true then objectTable=ui.editorObjects end
    if object then 
        table.insert(objectTable,object)
    end
    getAllObjects(nil,editorRequest)
end

function ui:addObjectToParent(object,parent)
    object.parent = parent
    table.insert(parent.children, object)
end

function ui.remove(object,editorRequest)
    local objectTable=ui.Objects
    if editorRequest and editorRequest==true then objectTable=ui.editorObjects end
    
    if object.parent then
        for i, v in ipairs(object.parent.children) do
            if v == object then
                table.remove(object.parent.children, i)
                break
            end
        end

        object.parent = nil
    else
        for i, v in ipairs(objectTable) do
            if v == object then
                table.remove(objectTable, i)
                break
            end
        end
    end

    getAllObjects(nil,editorRequest)
end

function ui:setFocus(object)
    if self.focusedObject and self.focusedObject ~= object then
        self.focusedObject.isFocused = false
    end

    self.focusedObject = object

    if object then
        object.isFocused = true
        love.keyboard.setTextInput(true)
    else
        love.keyboard.setTextInput(false)
    end
end
local function handleScroll(y)
       for _, obj in ipairs(ui.allObjects) do
        if obj.visible ~= false then
            if obj.handleMouseWheel then
                obj:handleMouseWheel(y)
            end
        end
    end
end
function ui:wheelmoved(x,y)
    handleScroll(y)
end

function ui:touchmoved(id, x, y, dx, dy, pressure)
    handleScroll(dy)
end

local function getScrollOffset(obj)
    local p = obj.parent
    local offsetY = 0

    while p do
        if p.class == "ScrollingFrame" then
            offsetY = offsetY + (p.positionY or 0)
        end
        p = p.parent
    end

    return offsetY
end
function ui:mousereleased(x, y, button)
    local clickedInput = nil

    local function scanFocus(list)
        for _, obj in ipairs(list) do
            if obj.visible ~= false then
                local isInsideScissor = true
                
                if obj.class == "ScrollingFrame" then
                    local absX, absY = obj:getAbsolutePosition()
                    
                    if x < absX or x > absX + obj.w or y < absY or y > absY + obj.h then
                        isInsideScissor = false
                    end
                end

                if obj.class == "TextInput" then
                    local absX, absY = obj:getAbsolutePosition()

                    if x > absX and x < absX + obj.w
                    and y > absY and y < absY + obj.h then
                        clickedInput = obj
                    end
                end
                if obj.children and isInsideScissor then
                    scanFocus(obj.children)
                end
            end
        end
    end

    scanFocus(self.Objects)

    self:setFocus(clickedInput)
end

function ui:textinput(t)
    if self.focusedObject and type(self.focusedObject.textinput) == "function" then
        self.focusedObject:textinput(t)
    end
end

function ui:keypressed(key)
    if self.focusedObject and type(self.focusedObject.keypressed) == "function" then
        self.focusedObject:keypressed(key)
    end
end

local attatchedToDisplayAxis = {}

---@param object UIObject
---@param axis string
---@param property string
---@param offset number
local function attatchToDisplayAxis(object, axis, property, offset)
    attatchedToDisplayAxis[#attatchedToDisplayAxis + 1] = {
        object = object,
        axis = axis,
        property = property,
        offset = offset
    }
end

local function applyNodeLayout(node, parentW, parentH)
    if node.anchorX == "stretch" then
        --node.x = 0
        node.w = parentW-(node.x)
    elseif node.anchorX == "center" then
        node.x = (parentW / 2) - (node.w / 2)
    elseif node.anchorX == "right" then
        node.x = parentW - node.w
    end

    if node.anchorY == "stretch" then
        --node.y = 0
        node.h = parentH-(node.y)
    elseif node.anchorY == "center" then
        node.y = (parentH / 2) - (node.h / 2)
    elseif node.anchorY == "bottom" then
        node.y = parentH - node.h
    end
end

local function applyLayout(editorRequest)

    local objectTable=ui.Objects

    local winX, winY = love.graphics.getWidth(), love.graphics.getHeight()
    
    if editorRequest and editorRequest==true then
        objectTable=ui.editorObjects
        winX=ui.editorViewportSize[1]
        winY=ui.editorViewportSize[2]
    end
    
    local function layoutRecursive(n, pW, pH)
        applyNodeLayout(n, pW, pH)
        if n.children then
            for _, child in ipairs(n.children) do
                layoutRecursive(child, n.w, n.h)
            end
        end
    end

    for _, obj in ipairs(objectTable) do
        layoutRecursive(obj, winX, winY)
    end
end

local function applyCommon(node, data)
    node.children = node.children or {}
    node.color = Color3.new(data.color[1], data.color[2], data.color[3])
    node.zIndex = data.zIndex
    node.name = data.name
    node.alpha = data.alpha
    node.visible = data.visible
    node.anchorX=data.anchorX
    node.anchorY=data.anchorY
end

local function attachNode(node, parent,editorRequest)
    if parent then
        node.parent = parent 
        table.insert(parent.children, node)
    else
        ui.addObject(node,editorRequest)
    end
end

local function buildNode(nodeData, parent,editorRequest)
    local newUIObject

    if nodeData.class == "Frame" then
        newUIObject = Frame.new(nodeData.position[1] * ui.Scale, nodeData.position[2] * ui.Scale, nodeData.size[1] * ui.Scale, nodeData.size[2] * ui.Scale)
    elseif nodeData.class == "TextButton" then
        newUIObject = TextButton.new(nodeData.position[1] * ui.Scale, nodeData.position[2] * ui.Scale, nodeData.size[1] * ui.Scale, nodeData.size[2] * ui.Scale)
    elseif nodeData.class == "TextLabel" then
        newUIObject = TextLabel.new(nodeData.position[1] * ui.Scale, nodeData.position[2] * ui.Scale, nodeData.size[1] * ui.Scale, nodeData.size[2] * ui.Scale)
    elseif nodeData.class == "TextInput" then
        newUIObject = TextInput.new(nodeData.position[1] * ui.Scale, nodeData.position[2] * ui.Scale, nodeData.size[1] * ui.Scale, nodeData.size[2] * ui.Scale, nodeData.text)
    elseif nodeData.class == "ImageButton" then
        newUIObject = ImageButton.new(nodeData.position[1] * ui.Scale, nodeData.position[2] * ui.Scale, nodeData.size[1] * ui.Scale, nodeData.size[2] * ui.Scale)
    elseif nodeData.class == "ImageLabel" then
        newUIObject = UIImage.new(nodeData.position[1] * ui.Scale, nodeData.position[2] * ui.Scale, nodeData.size[1] * ui.Scale, nodeData.size[2] * ui.Scale)
    elseif nodeData.class == "ScrollingFrame" then
        local vHeight = (nodeData.canvasHeight or nodeData.size[2]) * ui.Scale
        newUIObject = ScrollingFrame.new(nodeData.position[1] * ui.Scale, nodeData.position[2] * ui.Scale, nodeData.size[1] * ui.Scale, nodeData.size[2] * ui.Scale, vHeight)
    end

    if not newUIObject then return end

    applyCommon(newUIObject, nodeData)
    if nodeData.cornerRadius then
        newUIObject.cornerRadius=nodeData.cornerRadius
    end
    if nodeData.text then
        newUIObject.text = nodeData.text
        newUIObject.font = nodeData.font
        newUIObject.fontSize = nodeData.fontSize * ui.Scale
        newUIObject.textColor = Color3.new(nodeData.textColor[1], nodeData.textColor[2], nodeData.textColor[3])
        newUIObject.textAlpha = nodeData.textAlpha
        newUIObject.textAlignmentX = nodeData.textAlignmentX
        newUIObject.textAlignmentY = nodeData.textAlignmentY
        newUIObject.autoClip = nodeData.autoClip
        newUIObject.autoTextPos = nodeData.autoTextPos
    end

    if nodeData.image then
        if nodeData.imageColor then
            newUIObject.imageColor=Color3.new(nodeData.imageColor[1],nodeData.imageColor[2],nodeData.imageColor[3])
        end
        newUIObject.imageAlpha=nodeData.imageAlpha or 1
    end

    if newUIObject.class=="ScrollingFrame" then
        newUIObject.autoCanvasHeight=nodeData.autoCanvasHeight
    end

    if nodeData.backgroundBlurred then
        newUIObject.backgroundBlurred=nodeData.backgroundBlurred
    end

    if nodeData.shadow then
        newUIObject.shadow=nodeData.shadow
    end

    for i,v in pairs(nodeData) do
        if newUIObject[i] and not string.find(i:lower(),"color") and i~="fontSize" and i~="children" and i~="size" and i~="position" then   
            newUIObject[i]=v
            if i=="shadow" then
                newUIObject.shadowDirty=true
            end
        end
    end

    if nodeData.image then
        newUIObject.image = nodeData.image
    end

    if nodeData.attatchToDisplayAxis then
        attatchToDisplayAxis(newUIObject, nodeData.attatchToDisplayAxis, "w", 0)
    end

    attachNode(newUIObject, parent, editorRequest)

    for _, v in ipairs(nodeData.children or {}) do
        buildNode(v, newUIObject, editorRequest)
    end
end

local function updateEditorViewDPI()
    ui.editorViewportSize[1]=rawEditorViewSize[1]*ui.Scale
    ui.editorViewportSize[2]=rawEditorViewSize[2]*ui.Scale
end

function ui:loadJson(filePath, editorRequest)
    local realDir=love.filesystem.getRealDirectory(filePath)
    local jsonString
    if realDir then 
        jsonString=love.filesystem.read(filePath)
    else
        local file = io.open(filePath,"r")
        jsonString=file:read("*a")
    end
    
    local jsonTable = json.decode(jsonString)

    for i,v in pairs(jsonTable) do
        buildNode(v,nil, editorRequest)
        updateEditorViewDPI()
    end
    getAllObjects(nil, editorRequest)
    if editorRequest then
        applyLayout(editorRequest)
    end
end

function ui:setEditorViewportSize(w,h)
    rawEditorViewSize={w,h}
    updateEditorViewDPI()
end

function ui:requestMenuList(x,y,options,onSelect)
    local frame = Frame.new(x,y,200 * ui.Scale,32 * ui.Scale)
    local currentButton = 1

    local keys = {}
    local isDictionary = false

    for k in pairs(options) do
        if type(k) ~= "number" then
            isDictionary = true
        end
        table.insert(keys, k)
    end

    if isDictionary then
        table.sort(keys, function(a,b)
            return tostring(a):lower() < tostring(b):lower()
        end)
    end

    for _, i in ipairs(keys) do
        local v = options[i]
        local button

        if type(i) == "number" then
            button = TextButton.new(
                12*ui.Scale,(ui.listSpacing*(i-1))*ui.Scale,(200-24)*ui.Scale,ui.listSpacing*ui.Scale,v,
                function()
                    if onSelect then
                        onSelect(v)
                        self.remove(frame)
                    end
                end,
                "SpaceMono-Regular",14*ui.Scale
            )
        else
            button = TextButton.new(
                12*ui.Scale,(ui.listSpacing*(currentButton-1))*ui.Scale,(200-24)*ui.Scale,ui.listSpacing*ui.Scale,i,
                function()
                    if onSelect then
                        onSelect(i,v)
                        self.remove(frame)
                    end
                end,
                "SpaceMono-Regular",14*ui.Scale
            )
        end

        button.alpha = 0
        button.textColor = Color3.new(255,255,255)
        button.textAlignmentX = "left"
        button.parent = frame
        table.insert(frame.children,button)

        currentButton = currentButton + 1
    end

    frame.h = (ui.listSpacing*(currentButton-1))*ui.Scale
    frame.name = "menuList"
    frame.color = Color3.new(30,30,30)
    frame.shadow=true
    frame.shadowRadius=32
    frame.zIndex=99

    self.addObject(frame)
    return frame
end

function ui:draw(editorRequest)
    local objectTable=ui.Objects
    if editorRequest and editorRequest==true then objectTable=ui.editorObjects end

    table.sort(objectTable, function(a, b)
        return a.zIndex < b.zIndex
    end)

    for _, o in ipairs(objectTable) do
        if o.visible ~= false and o.draw then
            o:draw(editorRequest)
        end
    end
end

---@param name string
---@return UIObject?
function ui:getObject(name, recursive, list)
    list = list or self.Objects
    recursive=recursive or true

    for _, o in ipairs(list) do
        if o.name == name then
            return o
        end

        if (o.children and #o.children > 0) and recursive then
            local found = self:getObject(name, true, o.children)
            if found then
                return found
            end
        end
    end

    return nil
end

function ui:update(dt, editorRequest)
    local objectTable=ui.Objects
    local allObjectsTable=ui.allObjects
    if editorRequest and editorRequest==true then objectTable=ui.editorObjects allObjectsTable=ui.allEditorObjects end

    applyLayout(editorRequest)
    local overMouse=false
    for _, o in ipairs(objectTable) do
        if o.update then
            o:update(dt)
        end
    end
    for i,v in pairs(ui.allObjects) do
        if v.isHovered and v.isHovered==true then
            overMouse=true
        end
    end
    ui.mouseOverUI=overMouse
end

return ui