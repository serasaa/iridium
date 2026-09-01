require("globals").init()
local immediateUI= require("ui.immediate")
uiMan            = require("ui.uiManager")
log              = require("modules.log")
TextButton       = require("ui.objects.TextButton")
Color3           = require("types.Color3")
Frame            = require("ui.objects.Frame")
clamp            = require("modules.clamp")
TextLabel        = require("ui.objects.TextLabel")
TextInput        = require("ui.objects.TextInput")
local editor     = require("granite.studio")
local explorer   = require("explorer")
local UIImage    = require("ui.objects.UIImage")
local Camera     = require("types.Camera")
local gltf       = require("modules.loaders.gltf")
local uiScale=1
_G.uiMan=uiMan
onVita=false

local curSize=32

local rendering=false

local rtBounces=10
local rtSamples=1

local rtRes={1280,720}

local camLensSettings={
    anamorphicScale=.4,
    swirlStrength=.1,
    aperture=6.0, --its the second number of like f1/2
}

local globalDt=0

function quit()
    love.event.quit()
end

local ffi = require("ffi")

ffi.cdef[[
typedef int8_t int8;
typedef uint8_t uint8;
typedef int16_t int16;
typedef uint16_t uint16;
typedef uint32_t uint32;
typedef float float32;
]]


function string.unpack(fmt, str, offset)
    offset = offset or 1

    local size
    local ctype

    if fmt == "<b" then
        size = 1
        ctype = "int8_t"
    elseif fmt == "<B" then
        size = 1
        ctype = "uint8_t"
    elseif fmt == "<i2" then
        size = 2
        ctype = "int16_t"
    elseif fmt == "<I2" then
        size = 2
        ctype = "uint16_t"
    elseif fmt == "<I4" then
        size = 4
        ctype = "uint32_t"
    elseif fmt == "<f" then
        size = 4
        ctype = "float"
    else
        error("unsupported format "..fmt)
    end

    local buffer = ffi.new("uint8_t[?]", size)

    ffi.copy(
        buffer,
        str:sub(offset, offset + size - 1),
        size
    )

    local value = ffi.cast(ctype.."*", buffer)[0]

    return tonumber(value)
end

function string.split(inputstr, sep,wholeSeparator)
    if sep == nil then
        sep = "%s" 
    end
    local t = {}
    for str in string.gmatch(inputstr, "([^" .. sep .. "]+)") do
        table.insert(t, str)
    end
    return t
end

function dot(a,b)
    return a[1]*b[1] + a[2]*b[2] + a[3]*b[3]
end

function cross(a,b)
    return {
        a[2]*b[3] - a[3]*b[2],
        a[3]*b[1] - a[1]*b[3],
        a[1]*b[2] - a[2]*b[1]
    }
end

function normalize(v)
    local len = math.sqrt(dot(v,v))
    return {v[1]/len, v[2]/len, v[3]/len}
end

function tDeepClone(table,Cache)
    if type(table) ~= 'table' then
        return table
    end

    Cache = Cache or {}
    if Cache[table] then
        return Cache[table]
    end

    local New = {}
    Cache[table] = New
    for Key, Value in pairs(table) do
        New[tDeepClone( Key, Cache)] = tDeepClone( Value, Cache )
    end

    return New
end

function table.find(t,k)
    for i,v in pairs(t) do
        if v==k then return i end
    end
end

function getTableSize(t)
    local count = 0
    for _ in pairs(t) do
        count = count + 1
    end
    return count
end

table.clone=tDeepClone

function lerp(a, b, t)
    return a + (b - a) * t
end

local appendToUpdate={}

flags={}

for i,v in pairs(arg) do
    if type(v)=="string" then
        flags[v]=true
    end
end

local spinnerMode=false

ObjectTypes = {}
local objectUpdateTable={}

local gameState = "splash"
local loadState=0
local imageCache = {}

function appendUpdate(func, ...)
    appendToUpdate[#appendToUpdate + 1] = {
        func = func,
        args = {...}
    }
end

function removeUpdate(func)
    for i,v in pairs(appendToUpdate) do
        if v.func==func then
            table.remove(appendToUpdate,i)
        end
    end
end

function isInsideRectangle(x,y,rx,ry,rw,rh)
    return x > rx and x < rx + rw and y > ry and y < ry + rh
end

function isRectInside(inner, outer)
    return
        inner.x >= outer.x and
        inner.y >= outer.y and
        inner.x + inner.w <= outer.x + outer.w and
        inner.y + inner.h <= outer.y + outer.h
end

function getFont(name, size)
    size = size or 14
    if not name or not type(name)=="string" then return fontCache[love] end
    local key = name .. "_" .. size

    if not fontCache[key] then
        fontCache[key] = love.graphics.newFont(
            "fonts/" .. name..".ttf",
            size
        )
    end

    return fontCache[key]
end

function getImage(path)
    if imageCache[path] then
        return imageCache[path]
    end

    local ok, img = pcall(love.graphics.newImage, path)

    if not ok then
        error("Failed to load image: " .. tostring(path))
    end

    imageCache[path] = img
    return img
end

function drawGlow(x, y, w, h)
    local layers = 10

    for i = layers, 1, -1 do
        local t = i / layers
        love.graphics.setColor(1, 1, 1, 0.08 * t)

        local sizeX = (w or 2) + (1 - t) * 20
		local sizeY = (h or 2) + (1 - t) * 20
        love.graphics.ellipse("fill", x, y, sizeX,sizeY)
    end

    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.ellipse("fill", x, y, 2 or w, 2 or h)
end

function love.touchmoved(id, x, y, dx, dy, pressure)
    uiMan:touchmoved(id, x, y, dx, dy, pressure)
end


function love.keyreleased(key)
end

function love.gamepadpressed(joystick, button)
    inputDealer(button,true)
end

function love.textinput(t)
    uiMan:textinput(t)
end

function love.load()
    local dispX,dispY = love.window.getDesktopDimensions(1)
    local winW,winH = love.graphics.getDimensions()
    printWholeTable(love.parsedGameArguments)
    print(love.graphics.getRendererInfo())
    love.window.setMode(901,396,{borderless = true})

    local os=love.system.getOS()
    if os == "Android" then

        if winW < 700 or winH < 664 then
            local scaleW = winW / 700
            local scaleH = winH / 664

            uiScale = math.min(scaleW, scaleH)
            uiMan.listSpacing = 80
        end
    end
    
    if not onVita then
        enet = require("enet")
        socket = require("socket")
    end

    font = love.graphics.newFont("fonts/SpaceMono-Regular.ttf",14*uiScale)
    love.graphics.setFont(font)
    love.graphics.setBackgroundColor(0.063, 0.075, 0.114)

    uiMan.Scale=uiScale

    if flags["--editor"] then
        editor.init()
        gameState="editor"
    end
    local dpiScale = love.graphics.getDPIScale()
    local splashImage = UIImage.new(0,0,901/dpiScale,396/dpiScale,"assets/images/splash.png")

    uiMan.addObject(splashImage)

end

local function getViewport()
    local sw, sh = love.graphics.getPixelDimensions()
    local dpi = love.graphics.getDPIScale()

    local canvasW = rtRes[1]
    local canvasH = rtRes[2]

    local scale = math.min(
        sw / canvasW,
        sh / canvasH
    )

    scale = scale * love.graphics.getDPIScale()

    local drawW = canvasW * scale
    local drawH = canvasH * scale

    return
        (sw - drawW) * 0.5,
        (sh - drawH) * 0.5,
        drawW,
        drawH,
        scale
end

---@type love.Canvas
local mainCanvas
local snapshotCanvas

function rotateVectorAroundAxis(v, axis, angle)
    local cos = math.cos(angle)
    local sin = math.sin(angle)

    return {
        v[1]*cos + cross(axis, v)[1]*sin,
        v[2]*cos + cross(axis, v)[2]*sin,
        v[3]*cos + cross(axis, v)[3]*sin
    }
end

local camDragging=false

function love.mousepressed(x, y, button)
	local menu = uiMan:getObject("menuList",false)
	if menu then
		local inside =
			x >= menu.x and
			x <= menu.x + menu.w and
			y >= menu.y and
			y <= menu.y + menu.h

		if not inside then
			uiMan.remove(menu)
		end
	end
    if gameState=="editor" then
        editor.mousepressed(x,y,button)
    end

    if button==2 then
        camDragging=true
        love.mouse.setRelativeMode(true)
    end

    -- focus (not the ford focus)
    if button==1 and love.keyboard.isDown("lshift") then

        local u = x / sw
        local v = y / sh

        if u >= 0 and u <= 1 and v >= 0 and v <= 1 then
            local focusX = math.floor(u * rtRes[1])
            local focusY = math.floor(v * rtRes[2])
            
            ---@type love.ImageData
            local image = depthBuffer:newImageData()

            local focusDistance = image:getPixel(focusX,focusY)
            if focusDistance==0 then
                focusDistance=1e5
            end
            shaders.rt:send("focusDistance",focusDistance)
            
            resetAccumulation()
        end
    end
end

function love.mousereleased(x, y, button)
    if button==2 then
        camDragging=false
        love.mouse.setRelativeMode(false)
    end

    uiMan:mousereleased(x,y,button)
    editor.mousereleased(x,y,button)
end


function love.wheelmoved(x, y)
    if cam and rendering then
        if (y==math.floor(y) and x==0 ) or love.keyboard.isDown("lshift") then
            cam.fov=cam.fov-math.rad(1*y)
        else
            cam:rotateYaw((x*.1))
            cam:rotatePitch((y*.1))
            resetAccumulation()
        end
        resetAccumulation()
    end

    uiMan:wheelmoved(x,y)
    editor.wheelmoved(y)
end

function love.mousemoved(x, y, dx, dy)
    local w,h=love.graphics.getPixelDimensions()
    if camDragging and rendering then
        if cam then
            cam:rotateYaw(-(dx*.005))
            cam:rotatePitch((dy*.005))
            resetAccumulation()
        end
    end
    
    editor.mousemoved(x,y,dx,dy)
end

local function loadEXR(path)
    if not path then return end
    local file = io.open(path,"rb")
    print(file)
    
    local image = love.image.newImageData(love.filesystem.newFileData(file:read("*a"),"potato"))
    local hdri = love.graphics.newImage(image,{format="rgba32f"})

    local max = 0
    
    print(hdri:getDepthSampleMode())
    
    shaders.rt:send("hdri",hdri)
end

local function updateRendering()
    shaders.rt:send("rendering",rendering)
    if rendering then
        shaders.rt:send("samples",rtSamples)
        shaders.rt:send("bounces",rtBounces)
        resetAccumulation()
    else
        shaders.rt:send("samples",0)
        shaders.rt:send("bounces",0)
    end
end

function inputDealer(key,gamepad)
    if not uiMan.focusedObject and uiMan.mouseOverUI==false and gameState~="editor" then
    elseif uiMan.mouseOverUI and gamepad and key =="b" then
        local welcome=uiMan:getObject("welcome",false)
        if welcome then
            uiMan.remove(welcome)
        end
    elseif gameState=="editor" then
        editor.keypressed(key)
    end
    if key=="r" and love.keyboard.isDown("lshift","lctrl","lalt") then
        spinnerMode= not spinnerMode
    end
    if gameState~="editor" and not uiMan.focusedObject then
        if key=="f12" then
            gameState="editor"
            editor.init()
        end
        if key=="space" then
            rendering= not rendering
            updateRendering()
        end
        if key=="return" then
            
            if false then
                explorer:open("",{"gltf"},function (path)
                    if not path then return end
                    gltf.loadGltf(path)
                end)
            else
                love.window.showFileDialog("openfile",function(path)
                    
                    if not path[1] then return end
                    gltf.loadGltf(path[1])
                end,{
                        title="Select glTF",
                        filters={["Khronos glTF object"]="gltf"}
                    }
                )
            end
        end
        if key=="\\" then
            if false then
                explorer:open("",{"exr"},loadEXR)
            else
                love.window.showFileDialog("openfile",function(path)
                    if not path[1] then return end
                    loadEXR(path[1])
                end,{
                        title="Select EXR",
                        filters={["OpenEXR HDR image"]="exr",["Radiance HDR Image"]='hdr'}
                    }
                )
            end
        end
        if key=="s" and love.keyboard.isDown("lctrl") then
            local image = new:newImageData():encode("exr"):getString()
            local file = io.open("image.exr","wb")
            file:write(image)
            file:close()
        end
        if key=="s" and love.keyboard.isDown("lalt") then
            local image = depthBuffer:newImageData():encode("exr"):getString()
            local file = io.open("image.exr","wb")
            file:write(image)
            file:close()
        end
    end
    
end

function love.keypressed(key)
	inputDealer(key)
    if gameState~="loading" then
        uiMan:keypressed(key)
    end
end

function setupRaytracer()
    sw,sh=love.graphics.getPixelDimensions()
        cam = Camera.new()
        accumCanvasA = love.graphics.newCanvas(rtRes[1]/love.graphics.getDPIScale(), rtRes[2]/love.graphics.getDPIScale(), {
        format = "rgba32f",
        computewrite = true
    })

    accumCanvasB = love.graphics.newCanvas(rtRes[1]/love.graphics.getDPIScale(), rtRes[2]/love.graphics.getDPIScale(), {
        format = "rgba32f",
        computewrite = true
    })

    depthBuffer = love.graphics.newCanvas(rtRes[1]/love.graphics.getDPIScale(), rtRes[2]/love.graphics.getDPIScale(), {
        format = "rgba32f",
        computewrite = true
    })
    
    shaders.rt:send("focusDistance",50000)
    shaders.rt:send("hdri",love.graphics.newImage(love.image.newImageData(128,128,"rgba32f")))
    shaders.rt:send("depthBuffer",depthBuffer)
    
    shaders.rt:send("anamorphicScale",camLensSettings.anamorphicScale)
    shaders.rt:send("apertureF",camLensSettings.aperture)
    shaders.rt:send("swirlStrength",camLensSettings.swirlStrength)

    accumCanvasA:setFilter("nearest","nearest")
    accumCanvasB:setFilter("nearest","nearest")
    
end

local currentFrame = 0

function resetAccumulation()
    currentFrame = 0

    love.graphics.setCanvas(accumCanvasA)
    love.graphics.clear()

    love.graphics.setCanvas(accumCanvasB)
    love.graphics.clear()

    love.graphics.setCanvas(depthBuffer)
    love.graphics.clear()

    love.graphics.setCanvas()

end

function rayTrace()
    if not cam then return end

    local shader=shaders.rt
    shader:send("rtRes",rtRes)
    shader:send("camPos", cam.pos)
    shader:send("camForward", cam.forward)
    shader:send("camRight", cam.right)
    shader:send("camUp", cam.up)
    shader:send("fov", cam.fov)
end

function setupUI() 
    uiMan.Scale=uiScale
    uiMan.Objects={}
    
    love.window.setMode(1280*love.graphics.getDPIScale(),720*love.graphics.getDPIScale(),{vsync=false,resizable = true})
    fpsCounter=TextLabel.new(12,12,200,64,"wwwwww","SpaceMono-Regular",14)
    fpsCounter.textAlignmentX="left"
    fpsCounter.textAlignmentY="top"
    fpsCounter.alpha=0
    fpsCounter.textColor=Color3.new(255,255,255)
    fpsCounter.autoClip=false
    fpsCounter.autoTextPos=false

    uiMan.addObject(fpsCounter)

    mainCanvas=love.graphics.newCanvas()
    effectCanvas2=love.graphics.newCanvas(rtRes[1]/love.graphics.getDPIScale(), rtRes[2]/love.graphics.getDPIScale())
end

function love.draw()  
    sw,sh=love.graphics.getDimensions()
    
    local mx, my = love.mouse.getPosition()
    
    --shaders.rt:send("screenSize",{sdw,sdh})
    if mainCanvas then
        love.graphics.setCanvas()
        love.graphics.setColor(love.graphics.getBackgroundColor())
        love.graphics.rectangle("fill",0,0,sw,sh)
        love.graphics.setCanvas(mainCanvas)
    end

    if cursor then
        love.mouse.setVisible(false)
        cursor.w=curSize*uiScale
        cursor.h=curSize*uiScale
        cursor.x=mx
        cursor.y=my
    end

    if mainCanvas then
        love.graphics.setCanvas(mainCanvas)
        --love.graphics.clear()
    end

    love.graphics.setFont(font)
    if gameState=="editor" then
        love.graphics.setCanvas()
        editor.draw()
    elseif gameState=="render" then
        love.graphics.setColor(1,1,1,1)
        old = accumCanvasA
        new = accumCanvasB

        rayTrace()

        shaders.rt:send("frameCount", currentFrame)

        -- input accumulation texture
        shaders.rt:send("InputImage", old)

        -- output storage texture
        shaders.rt:send("OutputImage", new)

        local gx = math.ceil(rtRes[1] / 8)
        local gy = math.ceil(rtRes[2] / 8)

        love.graphics.dispatchThreadgroups(
            shaders.rt,
            gx,
            gy,
            1
        )

        -- swap
        accumCanvasA, accumCanvasB = accumCanvasB, accumCanvasA

        -- draw latest accumulation
        love.graphics.draw(accumCanvasA)
        
        love.graphics.setCanvas()
        currentFrame= currentFrame+1
        shaders.rt:send("frameCount",currentFrame)
       
        if effectCanvas2 then
            love.graphics.setShader(shaders.tonemap)

            local canvasW, canvasH = rtRes[1], rtRes[2]

            local scale = math.min(sw / canvasW, sh / canvasH)

            local drawW = canvasW * scale
            local drawH = canvasH * scale

            local x = (sw - drawW) * 0.5
            local y = (sh - drawH) * 0.5

            love.graphics.draw(accumCanvasA, x, y, 0, scale*love.graphics.getDPIScale(), scale*love.graphics.getDPIScale())

            love.graphics.setShader()
        end
    end

    love.graphics.setCanvas()
    
    uiMan:draw()
    log.draw() 
end

function love.resize(w, h)
    --mainCanvas = love.graphics.newCanvas()
end

local camSpeed = 25
function love.update(dt)
    globalDt=dt
    if gameState=="splash" then
        if loadState==1 then
            --load shaders
            shaders={
                ["grid"] = love.graphics.newShader("assets/shaders/grid.glsl"),
                ["tonemap"] = love.graphics.newShader("shaders/tonemap.glsl"),
                ["rt"] = love.graphics.newComputeShader("shaders/rt.glsl")
            }
            shaders.tonemap:send("exposure",.5)
            shaders.rt:send("bNoise",love.graphics.newImage("assets/images/noise.png",{computewrite=true}))
            setupRaytracer()

            if love.parsedGameArguments[1] then
                local loadedGLTF=false
                local loadedEXR=false
                ---@type string
                local mountSucc = love.filesystem.mountFullPath(love.parsedGameArguments[1],"scene")
                if mountSucc then
                    local sceneFolder=love.filesystem.getDirectoryItems("scene")
                    for i,v in pairs(sceneFolder) do
                        local path=love.filesystem.getRealDirectory("scene/"..v).."/"..v
                        print(path)
                        if string.find(v,".gltf") and not loadedGLTF then
                            gltf.loadGltf(path)
                            rendering=true
                            updateRendering()
                            loadedGLTF=true
                        elseif string.find(v,".exr") and not loadedEXR then
                            loadEXR(path)
                            updateRendering()
                            loadedEXR=true
                        end
                    end
                end
            end
        elseif loadState>2 then
            font       = love.graphics.getFont()
            fontCache = {["love"]=love.graphics.newFont()}
            setupUI()
            
            love.window.requestAttention(false)
            gameState="render"
        end
        loadState=loadState+1
    elseif gameState=="render" then
        shaders.rt:send("iTime",love.timer.getTime())
        for i = #appendToUpdate, 1, -1 do
            local entry = appendToUpdate[i]
            if entry.args[#entry.args] then
                entry.func(table.unpack(entry.args))
            else
                entry.func()
            end
        end
        if fpsCounter then
            local renderName, renderVer, gpuVendor, gpuDevice=love.graphics.getRendererInfo()
            
            local statsTable={}
            table.insert(statsTable,{"frametime", tostring(math.floor(dt*10000)/10)})
            table.insert(statsTable,{"API", renderName})
            table.insert(statsTable,{"API ver", renderVer})
            table.insert(statsTable,{"GPU", gpuDevice})

            local finalText=""
            for i,v in ipairs(statsTable) do
                finalText=finalText..v[1]..": "..v[2].."\n"
            end

            fpsCounter.text=finalText
        end
        if gameState=="editor" then
            editor.update(dt)
        end
        local move = {0, 0, 0}

        if love.keyboard.isDown("w") then
            if rendering then
                move[1] = move[1] + cam.forward[1]
                move[2] = move[2] + cam.forward[2]
                move[3] = move[3] + cam.forward[3]
                resetAccumulation()
            end
        end

        if love.keyboard.isDown("s") then
            if rendering then
                move[1] = move[1] - cam.forward[1]
                move[2] = move[2] - cam.forward[2]
                move[3] = move[3] - cam.forward[3]
                resetAccumulation()
            end
        end

        if love.keyboard.isDown("d") then
            if rendering then
                move[1] = move[1] + cam.right[1]
                move[2] = move[2] + cam.right[2]
                move[3] = move[3] + cam.right[3]
                resetAccumulation()
            end
        end

        if love.keyboard.isDown("a") then
            if rendering then
                move[1] = move[1] - cam.right[1]
                move[2] = move[2] - cam.right[2]
                move[3] = move[3] - cam.right[3]
                resetAccumulation()
            end
        end

        if love.keyboard.isDown("e") then
            if rendering then
                move[1] = move[1] - cam.up[1]
                move[2] = move[2] - cam.up[2]
                move[3] = move[3] - cam.up[3]
                resetAccumulation()
            end
        end

        if love.keyboard.isDown("q") then
            if rendering then
                move[1] = move[1] + cam.up[1]
                move[2] = move[2] + cam.up[2]
                move[3] = move[3] + cam.up[3]
                resetAccumulation()
            end
        end

        if move[1] ~= 0 or move[2] ~= 0 or move[3] ~= 0 then
            move = normalize(move)
        end

        if cam then
            cam.pos[1] = cam.pos[1] + move[1] * (camSpeed*dt)
            cam.pos[2] = cam.pos[2] + move[2] * (camSpeed*dt)
            cam.pos[3] = cam.pos[3] + move[3] * (camSpeed*dt)
        end

    end

    explorer:update(dt)
    uiMan:update(dt)
end