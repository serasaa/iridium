local UIImage = require "ui.objects.UIImage"
local fExplorer ={}

local curDir="C:\\Users\\shake"
local curDirObj={}

local fExplorerGui
local scrFrame
local bCancel
local bOk
local curDirText

local selectedFile
local theChosenOne

local explorerButtonsNumber=0
local explorerDirty=true
local fCallback
local sFileTypes

local function refreshHighlight()
    for i,v in pairs(scrFrame.children) do
        if selectedFile and selectedFile == v.text.."|"..v.fileType then
            v.alpha=1
            v.iconSpot.alpha=1
        else
            v.alpha=0
            v.iconSpot.alpha=0
        end
    end
end

local function safeForFont(str,font)
    font = font or love.graphics.getFont()
    local ok,msg = pcall(function()
        font:getWidth(str)
    end)
    if ok then
        return str
    end
    return "[unreadable file]"
end

local function selectFileCallback()
    uiMan.remove(fExplorerGui)
    if fCallback then
        if selectedFile then
            fCallback(curDir.."/"..string.split(selectedFile,"|")[1])
        else
            fCallback()
        end
    end
end

local function updateExplorer()
	scrFrame.children={}
	explorerButtonsNumber = 0

    local list = curDirObj
    local buttonSize = 32 * uiMan.Scale
    local padding = 8 * uiMan.Scale
    local xOffset = 32 * uiMan.Scale

    explorerButtonsNumber = 0
    local function recurse(objects, depth)
        local lastDirectChildNum = 0
        
        for _, o in ipairs(objects) do
            local currentButtonNum = explorerButtonsNumber
            lastDirectChildNum = currentButtonNum
            
            local bx = padding * depth
            local by = buttonSize * explorerButtonsNumber

            local fNameSplit=string.split(o[1],"%.")
            local fileType=fNameSplit[#fNameSplit]
            local fileAlpha=1
            if (#sFileTypes>=1 and not table.find(sFileTypes,fileType)) and o[2]~="folder" then
                fileAlpha=.4
            end

            local button = TextButton.new((bx*2) + xOffset, by + padding, scrFrame.w - bx - padding - xOffset, buttonSize, nil,
            function()
                local oShit=o[1].."|"..o[2]
				if selectedFile and selectedFile==oShit then
                    --send it part
                    if o[2]=="file" then selectFileCallback() end
                    --enter a folder part
                    if o[2]=="folder" then
                        if o[1]==".." then
                            local splitDir=string.split(curDir,"/")
                            local newDir=""
                            for i,v in pairs(splitDir) do
                                if i~=#splitDir then
                                    if i==1 then
                                        newDir=v 
                                    else
                                        newDir=newDir.."/"..v 
                                    end
                                end
                                curDir=newDir
                                explorerDirty=true
                            end
                        else
                            curDir=curDir.."/"..o[1]
                            explorerDirty=true
                        end
                    end
                else
                    if fileAlpha==1 then
                        selectedFile=oShit
                    end
                end
            end, "SpaceMono-Regular", 12 * uiMan.Scale)

            if explorerButtonsNumber ~= 0 then
                local stripe = Frame.new(padding, 0, button.w - (padding * 2), uiMan.Scale)
                stripe.color = Color3.new(255, 255, 255)
                stripe.alpha = .1
                stripe.parent = button
                table.insert(button.children, stripe)
            end

            local iconSpot = Frame.new(-xOffset-bx, 0, xOffset+bx, buttonSize)
            iconSpot.color = Color3.new(64, 156, 255)
            iconSpot.alpha = 0
            iconSpot.parent = button

			iconSpot.name="iconSpot"
            table.insert(button.children, iconSpot)

            if o[2]=="folder" then
                local iconSize=((iconSpot.h / 2))
                local stripeTheSequel = UIImage.new(0, 0, iconSize, iconSize)

                stripeTheSequel.x=padding
                stripeTheSequel.image="assets/images/folder.png"
                stripeTheSequel.imageAlpha = fileAlpha
                stripeTheSequel.alpha=0
                stripeTheSequel.anchorX="center"
                stripeTheSequel.anchorY="center"
                stripeTheSequel.imageColor = Color3.new(55,55,55)

                stripeTheSequel.parent = iconSpot
                table.insert(iconSpot.children, stripeTheSequel)
            end

            button.name = o[1] .. "|" .. explorerButtonsNumber
            button.fileType = o[2]
            button.text = safeForFont(o[1])
            button.iconSpot=iconSpot
            button.textAlignmentX = "left"
            button.textColor = Color3.new(255, 255, 255)
            button.textAlpha=fileAlpha
            button.color = Color3.new(64, 156, 255)
            button.alpha = 0

            button.parent = scrFrame
            table.insert(scrFrame.children, button)

            explorerButtonsNumber = explorerButtonsNumber + 1
		end
        
        return lastDirectChildNum
    end
    
    recurse(list, 1)
    
    scrFrame.canvasHeight = (buttonSize * explorerButtonsNumber)+padding*2
    curDirText.text=curDir
    return allObjectsTable
end

function fExplorer:update(dt)
    if fExplorerGui then
        refreshHighlight()
        if explorerDirty then
            explorerDirty=false
            curDirObj={}
            local tmpFoldDir = io.popen('dir "' .. curDir .. '" /ad /b'):lines()
            local tmpFileDir = io.popen('dir "' .. curDir .. '" /a-d /b'):lines()
            
            table.insert(curDirObj,{"..","folder"})
            for folder in tmpFoldDir do
                table.insert(curDirObj,{folder,"folder"})
            end
            for file in tmpFileDir do
                table.insert(curDirObj,{file,"file"})
            end
            updateExplorer()
        end
    end
end

local function loadUI()
    if uiMan:getObject("fExplorerBack",false) then return false, "Theres another explorer instance open" end
    uiMan:loadJson("ui/uiGroup/global/fileExplorer.json")
    scrFrame=uiMan:getObject("fExpContent")
    bCancel=uiMan:getObject("fExpCancel")
    bOk=uiMan:getObject("fExpOk")
    curDirText=uiMan:getObject("fExpCurDir")
    fExplorerGui=uiMan:getObject("fileExplorer",false)

    selectedFile=nil

    bCancel.onClick=function()
        selectedFile=nil
        selectFileCallback()
    end
end

---opens the explorer and returns the selected file
---@param startingDirectory string
---@param fileTypes table  --`{string}`
---@param callback function
function fExplorer:open(startingDirectory,fileTypes,callback)
    local dir = love.filesystem.getWorkingDirectory()
    if not dir then return false, "Invalid directory" end

    loadUI()

    sFileTypes=fileTypes or {}

    bOk.onClick=function()
        if selectedFile then
            selectFileCallback()
        end
    end
    curDir=dir
    explorerDirty=true
    fCallback=callback
end

function fExplorer:openFolder(startingDirectory,callback)
    local dir = startingDirectory or love.filesystem.getWorkingDirectory()
    dir = love.filesystem.getRealDirectory(dir)

    loadUI()
    explorerDirty=true
    sFileTypes={}

    bOk.onClick=function()
        if selectedFile then
            uiMan.remove(fExplorerGui)
            callback(curDir)
        end
    end
end

return fExplorer