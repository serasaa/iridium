local Color3 = require "types.Color3"
local TextButton = require "ui.objects.TextButton"
local ImageButton = require "ui.objects.ImageButton"
local UIImage = require "ui.objects.UIImage"
local ScrollingFrame = require "ui.objects.ScrollingFrame"
local json=require("modules.json")
local exporter = require("exporter")
local fExplorer=require("explorer")
local editor = {}

local uiObjectTypes = {
    "Frame",
    "TextButton",
    "TextLabel",
    "TextInput",
    "ImageButton",
    "ImageLabel",
    "ScrollingFrame",
}

local startingZoom=.25*uiMan.Scale
local cameraTransition={}
local dragging = false

local camera = {
    x = 0,
    y = 0,
    zoom = startingZoom,

    tx = 0,
    ty = 0,
    tzoom = startingZoom
}


--editor variables
---@type UIObject
local selectedObject=nil
local lastSelectedObject
---@type ScrollingFrame
local explorer
---@type ScrollingFrame
local inspector
---@type TextLabel
local curFileNameLabel

local currentFile="ui/uiGroup/menu/menu.json"

local followingSelected=false

local function evalMath(expr)
    expr = tostring(expr)

    if not expr:match("^[%d%+%-%*%/%(%).%s]+$") then
        return nil
    end

    local fn = load("return " .. expr, "expr", "t", {})
    if not fn then return nil end

    local ok, result = pcall(fn)
    if ok then return result end
    return nil
end

local function pointInRect(x,y,uiObj)
   if uiObj then
        local absX,absY=uiObj:getAbsolutePosition()
        return x > absX and x < absX + uiObj.w and y > absY and y < absY + uiObj.h
		
   else
        return nil
   end
end

local function updateCamera(dt)
    local speed = 12

    camera.x = lerp(camera.x, camera.tx, dt * speed)
    camera.y = lerp(camera.y, camera.ty, dt * speed)
    camera.zoom = lerp(camera.zoom, camera.tzoom, dt * speed)
end

local function moveCamera(dx,dy)
    camera.tx = camera.tx - dx / camera.zoom
    camera.ty = camera.ty - dy / camera.zoom
end

local function moveCameraTo(x,y)
    camera.tx = x
    camera.ty = y
end

local function updateCameraFollowing()
    if followingSelected then
        if selectedObject then
           	local ax, ay = selectedObject:getAbsolutePosition()

			local tx = ax + selectedObject.w / 2
			local ty = ay + selectedObject.h / 2

			moveCameraTo(tx,ty)
        else
            followingSelected=false
        end
    end
end

local function screenToWorld(screenX, screenY)
    local w,h = love.graphics.getDimensions()

    return
        camera.x + (screenX - w/2) / camera.zoom,
        camera.y + (screenY - h/2) / camera.zoom
end

local function worldToScreen(worldX, worldY)
    return
        (worldX - camera.x) * camera.zoom,
        (worldY - camera.y) * camera.zoom
end

local function resetCamera()

    local w, h = love.graphics.getDimensions()

    local targetWorldX = 0
    local targetWorldY = 0

    local targetX = targetWorldX - (w / camera.zoom) / 2
    local targetY = targetWorldY - (h / camera.zoom) / 2

    local dx = targetX - camera.x
    local dy = targetY - camera.y

    local distance = math.sqrt(dx * dx + dy * dy)

	local zoomOutAmount =
    math.min(
        6,
        1 + distance / 200
    )

    cameraTransition = {
        active = true,

        elapsed = 0,
        duration = math.min(3,1+ distance / 2000),

        startX = camera.x,
        startY = camera.y,

        targetWorldX = 0,
        targetWorldY = 0,

        startZoom = camera.zoom,
        endZoom = startingZoom*uiScale,

        zoomOutAmount = (zoomOutAmount*.3)^1.1
    }
end

local function cameraAttach()
    local w, h = love.graphics.getDimensions()

    love.graphics.push()

    love.graphics.translate(w / 2, h / 2)
    love.graphics.scale(camera.zoom)
    love.graphics.translate(-camera.x, -camera.y)
end

local function cameraDetach()
    love.graphics.pop()
end

local function getGridSize(cellSize)
    local targetSpacing = 96

    local level = math.floor(math.log(targetSpacing / (cellSize * camera.zoom)) / math.log(2))

    return cellSize * (2 ^ level)
end

local function drawGrid(baseCellSize, baseLineWidth)
	local shader=shaders.grid
    local w, h = love.graphics.getDimensions()
    local currentGridSize = getGridSize(baseCellSize)

    love.graphics.setShader(shader)

    shader:send("u_resolution", {w, h})
    shader:send("u_offset",     {camera.x, camera.y})
    shader:send("u_zoom",       camera.zoom)
    shader:send("u_gridSize",   currentGridSize)
    shader:send("u_lineWidth",  baseLineWidth)
    shader:send("u_axisWidth",   baseLineWidth * 3) 
    
    shader:send("u_gridColor",  {1, 1, 1, 0.1})
    shader:send("u_axisColor",  {1, 1, 1, 0.4})
	love.graphics.setColor(1,1,1)
    love.graphics.rectangle('fill', 0, 0, w, h)

    love.graphics.setShader()
end

local function saveJson(filePath, editorRequest)
	exporter.write(filePath,uiMan,true)
end

local inspectorDirty = true

local function updateInspector(updExplorer)

	if not selectedObject then
		lastSelectedObject = nil
		inspector.children = {}
		inspector.canvasHeight = 0
		return
	end

	if lastSelectedObject == selectedObject then
		return
	end

	lastSelectedObject = selectedObject

	inspector.children = {}
	inspector.canvasHeight = 0

	local rowSize=30*uiMan.Scale
	local headerSize=20*uiMan.Scale

	local padding=12*uiMan.Scale

	local keys = {}

	for k, _ in pairs(selectedObject) do
		table.insert(keys, k)
	end

	table.sort(keys, function(a, b)
		return tostring(a):lower() < tostring(b):lower()
	end)
	local currentProp=1
	local buttonNum=1
	for currentProp, i in ipairs(keys) do
		local v = selectedObject[i]
		-- make it have 0 width so i can stretch later
		local propertyFrame=Frame.new(
			padding,
			padding+((rowSize+headerSize+padding)*(currentProp-1)),
			0,
			headerSize+rowSize+padding
		)

		propertyFrame.alpha=0
		propertyFrame.anchorX="stretch"
		propertyFrame.name=tostring(i)

		
		uiMan:addObjectToParent(propertyFrame,inspector)

		local header=TextLabel.new(0,0,200*uiMan.Scale,headerSize,propertyFrame.name:upper(),"SpaceMono-Bold",14*uiMan.Scale)

		header.alpha=0
		header.anchorX="stretch"
		header.textAlignmentX="left"
		header.textAlignmentY="center"
		header.textColor=Color3.new(150,150,150)

		uiMan:addObjectToParent(header,propertyFrame)

		local propLabel=TextLabel.new(0,1+rowSize/2,200*uiMan.Scale,rowSize,type(v),"SpaceMono-Regular",14*uiMan.Scale)

		propLabel.alpha=0
		propLabel.anchorX="stretch"
		propLabel.textAlignmentX="left"
		propLabel.textAlignmentY="center"
		propLabel.textColor=Color3.new(255,255,255)

		local propValue
		if type(v)=="number" then
			propValue=TextInput.new(0,rowSize,100*uiMan.Scale,30*uiMan.Scale,v,function(text)
				local numba=evalMath(text)
				if numba then
					if i=="x" or i=="y" or i=="w" or i=="h" or i=="fontSize" then
						selectedObject[i]=numba*uiMan.Scale
						uiMan:update(0,true)
					else
						selectedObject[i]=numba
					end
					--rebuildPreviewUI()
				end
				--propValue.text=tostring(numba)
			end,"SpaceMono-Regular",14*uiMan.Scale)

			if i=="x" or i=="y" or i=="w" or i=="h" or i=="fontSize" then
				propValue.text=v/uiMan.Scale
			end
			propValue.anchorY="center"
			propValue.anchorX="right"
			propValue.textAlignmentX="left"
			propValue.textAlignmentY="center"
			propValue.color=Color3.new(10,10,10)
			propValue.textColor=Color3.new(255,255,255)
		elseif type(v)=="string" and i:lower()~="image" then
			propValue=TextInput.new(0,rowSize,100*uiMan.Scale,30*uiMan.Scale,v,function(text)
				if text then
					selectedObject[i]=text
					if i=="name" then
						updExplorer()
					end
					uiMan:update(0,true)
				end
				propValue.text=selectedObject[i]
			end,"SpaceMono-Regular",14*uiMan.Scale)

			propValue.anchorY="center"
			propValue.anchorX="right"
			propValue.textAlignmentX="left"
			propValue.textAlignmentY="center"
			propValue.color=Color3.new(10,10,10)
			propValue.textColor=Color3.new(255,255,255)
        elseif type(v)=="string" and i:lower() == "image" then
            propValue=TextButton.new(0,rowSize,100*uiMan.Scale,30*uiMan.Scale,v,function()
				fExplorer:open("assets/",{"png","jpg","jpeg"},function(path)
                    local realDir=love.filesystem.getRealDirectory("assets/").."/"
                    local isInside = string.find(path,realDir,nil,true)
                    local finalPath=path

                    if isInside then finalPath = string.gsub(path,realDir,"") end
                    selectedObject[i]=finalPath
                end)
			end,"SpaceMono-Regular",14*uiMan.Scale)

			propValue.anchorY="center"
			propValue.anchorX="right"
			propValue.textAlignmentX="left"
			propValue.textAlignmentY="center"
			propValue.color=Color3.new(10,10,10)
			propValue.textColor=Color3.new(255,255,255)
		elseif type(v)=="table" and string.find(i:lower(),"color") then
			propValue=TextInput.new(0,rowSize,100*uiMan.Scale,30*uiMan.Scale,v,function(text)
				if text then
					local stringSplit=string.split(text,",")
					local finalTable={}
					for i2,v2 in pairs(stringSplit) do
						local color="R"
						if i2==1 then color="R" end
						if i2==2 then color="G" end
						if i2==3 then color="B" end
						finalTable[color]=tonumber(v2)/255
					end
					selectedObject[i]=finalTable
				end
			end,"SpaceMono-Regular",14*uiMan.Scale)

			local order = { "R", "G", "B" }

			local cTable=selectedObject[i]
			local finalString=""
			for i2,v2 in pairs(order) do
				if v2=="R" then
					finalString=math.floor(cTable[v2]*255)
				else
					finalString=finalString..","..math.floor(cTable[v2]*255)
				end
			end

			propValue.text=finalString
			propValue.anchorY="center"
			propValue.anchorX="right"
			propValue.textAlignmentX="left"
			propValue.textAlignmentY="center"
			propValue.color=Color3.new(10,10,10)
			propValue.textColor=Color3.new(255,255,255)
		end

		if propValue then
			uiMan:addObjectToParent(propValue,propertyFrame)
		end

		uiMan:addObjectToParent(propLabel,propertyFrame)

		currentProp=currentProp+1
		buttonNum=buttonNum+1
	end

	local totalCanvasSize=padding

	for i,v in pairs(inspector.children) do
		totalCanvasSize=totalCanvasSize+v.h+padding
	end

	local weirdMath=headerSize+rowSize+padding

    inspector.canvasHeight = (weirdMath)+((weirdMath)*(buttonNum-1))
    
    return allObjectsTable
end

local explorerButtonsNumber=0
local explorerButtonSize=0
local explorerPadding=0
local explorerXOffset=0
local function updateExplorer()
	explorer.children = {}
	explorerButtonsNumber = 0

    local list = uiMan.editorObjects
    local buttonSize = 32 * uiMan.Scale
    local padding = 8 * uiMan.Scale
    local xOffset = 32 * uiMan.Scale

    explorerButtonSize = buttonSize
    explorerPadding = padding
    explorerXOffset = xOffset

    explorerButtonsNumber = 0
    local function recurse(objects, depth)
        local lastDirectChildNum = 0
        
        for _, o in ipairs(objects) do
            local currentButtonNum = explorerButtonsNumber
            lastDirectChildNum = currentButtonNum
            
            local bx = padding * depth
            local by = buttonSize * explorerButtonsNumber

            local button = TextButton.new(bx + xOffset, by + padding, explorer.w - bx - padding - xOffset, buttonSize, nil,
            function ()
                selectedObject=o
				inspectorDirty = true
				updateInspector(updateExplorer)
				
            end, "SpaceMono-Regular", 12 * uiMan.Scale)

            if explorerButtonsNumber ~= 0 then
                local stripe = Frame.new(padding, 0, button.w - (padding * 2), uiMan.Scale)
                stripe.color = Color3.new(255, 255, 255)
                stripe.alpha = .1
                stripe.parent = button
                table.insert(button.children, stripe)
            end

            local iconSpot = Frame.new(-xOffset, 0, xOffset, buttonSize)
            iconSpot.color = Color3.new(64, 156, 255)
            iconSpot.alpha = 0
            iconSpot.parent = button
			iconSpot.name="iconSpot"
            table.insert(button.children, iconSpot)
            local stripeTheSequel = Frame.new(0, iconSpot.h / 2, ((iconSpot.w / 2)) - padding, uiMan.Scale)

			stripeTheSequel.x=padding
            stripeTheSequel.alpha = .1
            stripeTheSequel.color = Color3.new(255, 255, 255)
            stripeTheSequel.parent = iconSpot
            table.insert(iconSpot.children, stripeTheSequel)

            button.name = o.name .. "_" .. explorerButtonsNumber
            button.refObject = o
            button.text = o.name
            button.textAlignmentX = "left"
            button.textColor = Color3.new(255, 255, 255)
            button.color = Color3.new(64, 156, 255)
            button.alpha = 0

            button.parent = explorer
            table.insert(explorer.children, button)

            explorerButtonsNumber = explorerButtonsNumber + 1

            if o.children and #o.children > 0 then
				
				local one=false
				local function countAllDescendants(objects)
					local count = 0
					for _, obj in ipairs(objects) do
						count = count + 1
						if obj.children then
							one=true
							count = count + countAllDescendants(obj.children)
						end
					end
					return count
				end

				local totalBranchSize = countAllDescendants(o.children)
				local lineHeight = (totalBranchSize * buttonSize) 

				local verticalLine = Frame.new(
					iconSpot.w / 2,
					buttonSize / 2,
					uiMan.Scale,
					lineHeight
				)
							
				verticalLine.alpha = .1
				verticalLine.color = Color3.new(255, 255, 255)
				verticalLine.parent = iconSpot
				table.insert(iconSpot.children, verticalLine)
				recurse(o.children, depth + 1)
			end
		end
        
        return lastDirectChildNum
    end
    
    recurse(list, 1)
    
    explorer.canvasHeight = buttonSize * explorerButtonsNumber
    
    return allObjectsTable
end

local function uniqueEditorObjectName(base)
    local index = 1
    local name = base

    while uiMan:getObject(name, true, uiMan.editorObjects) do
        index = index + 1
        name = base .. "_" .. index
    end

    return name
end

local function createEditorObject(className,parent)
    local scale = uiMan.Scale
    local x, y = 0, 0
    local w, h = 100 * scale, 100 * scale
    local obj

    if className == "Frame" then
        obj = Frame.new(x, y, w, h)
    elseif className == "TextButton" then
        obj = TextButton.new(x, y, w, 40 * scale, "button", nil, "SpaceMono-Regular", 14 * scale)
    elseif className == "TextLabel" then
        obj = TextLabel.new(x, y, w, 40 * scale, "label", "SpaceMono-Regular", 14 * scale)
    elseif className == "TextInput" then
        obj = TextInput.new(x, y, w, 40 * scale, "", nil, "SpaceMono-Regular", 14 * scale)
    elseif className == "ImageButton" then
        obj = ImageButton.new(x, y, w, h)
    elseif className == "ImageLabel" then
        obj = UIImage.new(x, y, w, h)
    elseif className == "ScrollingFrame" then
        obj = ScrollingFrame.new(x, y, w, h, h * 2)
    end

    if not obj then
        return
    end

    obj.class = className == "ImageLabel" and "ImageLabel" or (obj.class or className)
    obj.name = uniqueEditorObjectName(className)
    obj.alpha = 1
    obj.visible = true

    if parent then
		uiMan:addObjectToParent(obj,parent)
	else
		uiMan.addObject(obj, true)
	end
    selectedObject = obj
    lastSelectedObject = nil
    updateExplorer()
    updateInspector(updateExplorer)
    return obj
end

local function drawPreviewUI()
    love.graphics.setColor(0, 0, 0)
    love.graphics.rectangle("fill",0,0,uiMan.editorViewportSize[1],uiMan.editorViewportSize[2])
    uiMan:draw(true)
	if selectedObject then
		local absX,absY=selectedObject:getAbsolutePosition()
		love.graphics.setColor(64/255, 156/255, 1)
		love.graphics.setLineWidth((editorSelectedLineThickness*uiMan.Scale)/(camera.zoom))
		love.graphics.rectangle("line",absX,absY,selectedObject.w,selectedObject.h)
	end
end

local function reloadUI()
	uiMan.editorObjects={}
	uiMan.allEditorObjects={}

    local cFileSplit=string.split(string.gsub(currentFile,"/","%."),".")
    local cFileName=cFileSplit[#cFileSplit-1].."."..cFileSplit[#cFileSplit]

	uiMan:loadJson(currentFile,true)

    curFileNameLabel.text=cFileName:upper()

	updateInspector(updateExplorer)
	updateExplorer()
end

local function hitTestObject(obj,x,y)
    for i=#obj.children,1,-1 do
        local hit=hitTestObject(obj.children[i],x,y)
        if hit then
            return hit
        end
    end

    if pointInRect(x,y,obj) then
        return obj
    end

    return nil
end

local function clickedObject(mx,my)
     for i=#uiMan.editorObjects,1,-1 do
        local hit=hitTestObject(uiMan.editorObjects[i],mx,my)
        
        if hit then
            return hit
        end
    end
end

function editor.init()
    print("loadedd")
    love.graphics.setBackgroundColor(0.071, 0.086, 0.11)
    startingZoom=.5*uiMan.Scale
    camera.tzoom=startingZoom
    camera.zoom=startingZoom

    uiMan.Objects={}
    uiMan:loadJson("ui/uiGroup/studio/layout.json")

    --load ui to be edited
    for i,v in pairs(uiMan.allEditorObjects) do
        uiMan.remove(v,true)
    end

	local menuBar=uiMan:getObject("menuBar")
	---@type TextButton
	local fileButton=uiMan:getObject("file")
	---@type TextButton
	local newButton=uiMan:getObject("new")
	explorer=uiMan:getObject("explorer")
	inspector=uiMan:getObject("inspector")
    ---@type TextLabel
	curFileNameLabel=uiMan:getObject("currentFileName")

    reloadUI()

	menuBar.shadow=true
	menuBar.shadowRadius=16
	fileButton.onClick=function()
		uiMan:requestMenuList(fileButton.x,fileButton.y+fileButton.h,{
			"New Interface",
            "Open",
			"Save",
            "Save To",
			"Exit"
		},function(selection)
			if selection=="Exit" then
				love.event.quit()
			elseif selection=="Save" then
				saveJson(currentFile,true)
			elseif selection=="New Interface" then
				local timeStampString=os.date("%d%m%Y%H%M%S")
				uiMan.editorObjects={}
				uiMan.allEditorObjects={}
				exporter.write("granite/interfaces/newInterface"..timeStampString..".json",uiMan,true)

				currentFile="granite/interfaces/newInterface"..timeStampString..".json"
				reloadUI()
            elseif selection=="Open" then
                fExplorer:open("ui/objects",{"json"},function(filepath)
                    if filepath then
                        currentFile=filepath
                        reloadUI()   
                    end
                end)
            elseif selection=="Save To" then
                fExplorer:openFolder("",function(path)
                    if path then
                        local cFileSplit=string.split(string.gsub(currentFile,"/","%."),".")
                        local cFileName=cFileSplit[#cFileSplit-1].."."..cFileSplit[#cFileSplit]
                        saveJson(path.."/"..cFileName,true)
                    end
                end)
			end
		end).color=menuBar.color
	end
	newButton.onClick=function()
		uiMan:requestMenuList(newButton.x,newButton.y+newButton.h,uiObjectTypes,function(className)
			createEditorObject(className)
		end).color=menuBar.color
	end
	updateExplorer()
end

function editor.mousepressed(x, y, button)
    if not uiMan.mouseOverUI then
        if button==2 then
        	dragging=true
        end
        if button==1 then
			--object select shit
           	local wx, wy = screenToWorld(x, y)
			local hit = clickedObject(wx, wy)
			selectedObject = hit
			inspectorDirty = true
			updateInspector(updateExplorer)
        end
    end
end

function editor.mousereleased(x, y, button)
    if button == 2 then
        dragging = false
        local wx, wy = screenToWorld(x, y)
        local hit = clickedObject(wx, wy)
        
        if hit and not dragging then
            uiMan:requestMenuList(x, y, {
                "Create Child",
                "Duplicate",
                "Delete"
            }, function(selection)
                if selection == "Create Child" then
                    uiMan:requestMenuList(x, y, uiObjectTypes, function(class)
                        createEditorObject(class, hit)
                    end)
                elseif selection == "Delete" then
                    uiMan.remove(hit, true)
                    selectedObject = nil
                    updateExplorer()
                    updateInspector(updateExplorer)
                end
            end)
        end
    end
end

function editor.mousemoved(x,y,dx,dy)
    if dragging then
		followingSelected=false
        moveCamera(dx,dy)
    end
    if selectedObject then
        if draggingPhysics==true then
            movingSelected=true
        end
    end
end

function editor.keypressed(key)
    if not uiMan.focusedObject then
		if key=="c" then
			if selectedObject then
				followingSelected=true
			end
		end
	end
end

function editor.wheelmoved(y)
    if uiMan.mouseOverUI==false then
		local factor = 1.1
		if y > 0 then
			camera.tzoom = camera.tzoom * factor
		elseif y < 0 then
			camera.tzoom = camera.tzoom / factor
		end
	end
end

function editor.draw()
    love.mouse.setVisible(true)
    drawGrid(32,1)
    cameraAttach()
    
    drawPreviewUI()
    
    cameraDetach()
end

function editor.update(dt)
	local w,h=love.graphics.getDimensions()
    if cameraTransition.active then
        local t
        cameraTransition.elapsed = cameraTransition.elapsed + dt
        t = math.min(
                cameraTransition.elapsed /
                cameraTransition.duration,
                1
            )
        local smooth = t*t*t*(t*(6*t-15)+10) --t * t * (3 - 2 * t)
        local zoomArc = math.sin(t * math.pi)
        camera.tzoom =
            cameraTransition.endZoom -
            zoomArc * cameraTransition.zoomOutAmount
        local w, h =
            love.graphics.getDimensions()
        local targetX =
            cameraTransition.targetWorldX -
            (w / camera.tzoom) / 2
        local targetY =
            cameraTransition.targetWorldY -
            (h / camera.tzoom) / 2
        camera.tx =
            cameraTransition.startX +
            (targetX - cameraTransition.startX) * smooth
        camera.ty =
            cameraTransition.startY +
            (targetY - cameraTransition.startY) * smooth
        if t >= 1 then
            cameraTransition.active = false
            camera.tzoom =
                cameraTransition.endZoom
            camera.tx =
                cameraTransition.targetWorldX -
                (w / camera.tzoom) / 2
            camera.ty =
                cameraTransition.targetWorldY -
                (h / camera.tzoom) / 2
        end
    end

	if explorer then
		explorer.canvasHeight=(explorerPadding*2)+(explorerButtonSize*explorerButtonsNumber)
		for i,v in pairs(uiMan:getObject("explorer").children) do
			if v.refObject==selectedObject then
				v.alpha=1
				uiMan:getObject("iconSpot",false,v.children).alpha=1
			else
				v.alpha=0
				uiMan:getObject("iconSpot",false,v.children).alpha=0
			end
		end
	end
	updateCameraFollowing()
    updateCamera(dt)
end

return editor