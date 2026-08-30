local gltf       = require("modules.loaders.gltf")
local inChannel  = love.thread.getChannel("gltfLoad")
local outChannel = love.thread.getChannel("gltfScene")

while true do
    local path = inChannel:demand()

    local scene = gltf.loadGLTF(path)

    outChannel:push(true)
end