local gltfLoader={}
local gltf       = require("modules.gltf")
local BVHBoundingBox = require("types.BVHBoundingBox")
local BVHNode        = require("types.BVHNode")

local pi=0.14159265359

local function unescapePercent(str)
	return (str:gsub("%%(%x%x)", function(x) return string.char(tonumber(x, 16)) end))
end

local function resolveURI(uri, basePath)
	-- https://developer.mozilla.org/en-US/docs/Web/HTTP/Basics_of_HTTP/Data_URLs

	-- URI ABNF: https://datatracker.ietf.org/doc/html/rfc3986#appendix-A
	uri = unescapePercent(uri)
	local nzncend = (uri:find("/")) or 0
	local firstcolon = (uri:find(":")) or 0
	if firstcolon < nzncend or nzncend == 1 or uri:len() == 0 then
		error("expected data URI or relative path")
	end
	local file = io.open(basePath .. uri, "rb")
	local data = file:read("*a")
	file:close()
	return data
end

function printWholeTable(t, indent, seen)
        indent = indent or ""
        seen = seen or {}

        if seen[t] then
            print(indent .. "<already printed>")
            return
        end

        seen[t] = true

        for k, v in pairs(t) do
            if type(v) == "table" then
                print(indent .. tostring(k) .. ":")
                printWholeTable(v, indent .. "  ", seen)
            else
                print(indent .. tostring(k), v)
            end
        end
    end

local function offsetVertex(vertex, translation)
    return {
        vertex[1] + (translation[1] or 0),
        vertex[2] + (translation[2] or 0),
        vertex[3] + (translation[3] or 0)
    }
end

local function quatRotate(v, q)
    local x,y,z,w = q[1],q[2],q[3],q[4]

    local qv = {x,y,z}

    local uv = {
        qv[2]*v[3]-qv[3]*v[2],
        qv[3]*v[1]-qv[1]*v[3],
        qv[1]*v[2]-qv[2]*v[1]
    }

    local uuv = {
        qv[2]*uv[3]-qv[3]*uv[2],
        qv[3]*uv[1]-qv[1]*uv[3],
        qv[1]*uv[2]-qv[2]*uv[1]
    }

    return {
        v[1] + 2*(w*uv[1]+uuv[1]),
        v[2] + 2*(w*uv[2]+uuv[2]),
        v[3] + 2*(w*uv[3]+uuv[3])
    }
end

local function sendTextures(basePath,textures)
    local images={}
    
    for i,tex in pairs(textures or {}) do
        
        print(tex.id,basePath..tex.source.uri.."|")
        local imageFile=resolveURI(tex.source.uri,basePath)
        local imageData=love.graphics.newImage(love.filesystem.newFileData(imageFile,""))
        
        images[i]=imageData
    end
    
    if #images ~= 0 then
        shaders.rt:send("images",unpack(images))
    end
end

local function sendMaterials(materials)
    local materialData = {}
    for i, material in ipairs(materials) do
        -- Flatten one material into floats
        local base = material.pbrMetallicRoughness
        if base and not material.pbrMetallicRoughness.baseColorTexture then
            base=material.pbrMetallicRoughness.baseColorFactor
        elseif base and material.pbrMetallicRoughness.baseColorTexture or material.emissiveTexture then
            base={math.huge,0,0}
        else
            base={.8,.8,.8}
        end
        table.insert(materialData, math.min(base[1],1))-- color r
        table.insert(materialData, math.min(base[2],1))-- color g
        table.insert(materialData, math.min(base[3],1))-- color b

        table.insert(materialData, material.emissiveFactor[1])-- emissive r
        table.insert(materialData, material.emissiveFactor[2])-- emissive g
        table.insert(materialData, material.emissiveFactor[3])-- emissive b
        if material.pbrMetallicRoughness and not material.pbrMetallicRoughness.metallicRoughnessTexture then
            table.insert(materialData, material.pbrMetallicRoughness.roughnessFactor)
        elseif material.pbrMetallicRoughness and material.pbrMetallicRoughness.metallicRoughnessTexture then
            print("roughness map")
            table.insert(materialData,material.pbrMetallicRoughness.metallicRoughnessTexture.texture.id+2)
        else
            print("default roughness")
            table.insert(materialData,.5)
        end

        table.insert(materialData, 1.0) -- clearcoat r
        table.insert(materialData, 1.0) -- clearcoat g
        table.insert(materialData, 1.0) -- clearcoat b
        if material.pbrMetallicRoughness and not material.pbrMetallicRoughness.metallicRoughnessTexture then
            
            table.insert(materialData, material.pbrMetallicRoughness.metallicFactor) -- clearcoat weight -- thats falsified information thats metalness
        else
            table.insert(materialData, 0) 
        end
        local strength = 0
        if material.extensions and material.extensions.KHR_materials_emissive_strength then
            strength = material.extensions.KHR_materials_emissive_strength.emissiveStrength
        end

        table.insert(materialData, strength)

        -- if true then is emissive texture
        if material.emissiveTexture then
            table.insert(materialData,material.emissiveTexture.texture.id)
        elseif base[1]==math.huge then
            print("textured")
            table.insert(materialData,material.pbrMetallicRoughness.baseColorTexture.texture.id)
        else
            table.insert(materialData,-1)
        end

        --material type
        local matType=0
        local ior=1.5

        --glass
        if material.extensions and material.extensions.KHR_materials_transmission then
            matType=1 --backwards compatibility moment
            if material.extensions.KHR_materials_transmission.transmissionTexture then
                print("going index")
                print(matType)
                matType=material.extensions.KHR_materials_transmission.transmissionTexture.index+3
            end
            if material.extensions.KHR_materials_ior then
                ior=material.extensions.KHR_materials_ior.ior
            end
            if material.extensions.KHR_materials_transmission.transmissionFactor==.5 then
                --thin glass
                matType=2
            end
        end
        table.insert(materialData,matType)
        table.insert(materialData,ior)
    end
    if  #materialData>0 then
            
        materialBuffer = love.graphics.newBuffer(
            "float",
            #materialData,
            { shaderstorage = true }
        )

        materialBuffer:setArrayData(materialData)
        shaders.rt:send("MaterialBuffer", materialBuffer)
    end
end

function mirrorX(v)
    return {v[1], v[2], -v[3]}
end

local function getSplitAxis(box)
    local size = {
        box.maxBounds[1] - box.minBounds[1],
        box.maxBounds[2] - box.minBounds[2],
        box.maxBounds[3] - box.minBounds[3]
    }

    if size[1] > size[2] and size[1] > size[3] then
        return 1
    elseif size[2] > size[3] then
        return 2
    else
        return 3
    end
end

local curBVH=0
function buildBVH(triangles)
    local node = BVHNode.new()
    node.boundingBox = BVHBoundingBox.new()

    for _,tri in ipairs(triangles) do
        node.boundingBox:expandBounds(tri.posA)
        node.boundingBox:expandBounds(tri.posB)
        node.boundingBox:expandBounds(tri.posC)
    end
    node.isLeaf=0


    if #triangles <= 1 then
        node.triangles = triangles
        node.isLeaf = 1
        return node
    end

    local axis = getSplitAxis(node.boundingBox)

    table.sort(triangles,function(a,b)
        return a.center[axis] < b.center[axis]
    end)

    local middle = math.floor(#triangles/2)

    local left={}
    local right={}

    for i=1,middle do
        left[#left+1]=triangles[i]
    end

    for i=middle+1,#triangles do
        right[#right+1]=triangles[i]
    end

    node.childA = buildBVH(left)
    node.childB = buildBVH(right)
    return node
end

local NODE_SIZE = 12

local function flattenBVH(node, nodes, triangles)
    local index = #nodes / NODE_SIZE

    -- reserve space for this node
    for i = 1, NODE_SIZE do
        nodes[#nodes+1] = 0
    end

    local left = -1
    local right = -1
    if node.isLeaf==0 then
        left = flattenBVH(node.childA, nodes, triangles)
        right = flattenBVH(node.childB, nodes, triangles)
    end
    local triStart = #triangles
    local triCount = 0

    if node.isLeaf==1 then
        for _, tri in ipairs(node.triangles) do
            triangles[#triangles+1] = tri.id
            triCount = triCount + 1
        end
    end


    local i = index * NODE_SIZE + 1

    -- bounds
    nodes[i+0] = node.boundingBox.minBounds[1]
    nodes[i+1] = node.boundingBox.minBounds[2]
    nodes[i+2] = node.boundingBox.minBounds[3]

    nodes[i+3] = left

    nodes[i+4] = node.boundingBox.maxBounds[1]
    nodes[i+5] = node.boundingBox.maxBounds[2]
    nodes[i+6] = node.boundingBox.maxBounds[3]

    nodes[i+7] = right
    
    nodes[i+8] = triStart 
    nodes[i+9] = triCount

    return index
end

local function transformPoint(p, node)
    p = {
        p[1] * node.scale[1],
        p[2] * node.scale[2],
        p[3] * node.scale[3]
    }

    p = quatRotate(p, node.rotation)

    p = {
        p[1] + node.translation[1],
        p[2] + node.translation[2],
        p[3] + node.translation[3]
    }

    return p
end

local function normalize(v)
    local len = math.sqrt(
        v[1]*v[1] +
        v[2]*v[2] +
        v[3]*v[3]
    )

    if len == 0 then
        return {0, 0, 0}
    end

    return {
        v[1] / len,
        v[2] / len,
        v[3] / len
    }
end

local function transformNormal(n, node)
    -- Inverse scale
    local x = n[1] / node.scale[1]
    local y = n[2] / node.scale[2]
    local z = n[3] / node.scale[3]

    -- Rotation
    local rotated = quatRotate({x, y, z}, node.rotation)

    -- Normals should stay normalized
    return normalize(rotated)
end

function gltfLoader.loadGltf(path)
    local basePath=path:sub(1, path:find("[/\\][^/\\]*$") or 0)
    local minBounds = {math.huge, math.huge, math.huge}
    local maxBounds = {-math.huge, -math.huge, -math.huge}

    local function expandBounds(v)
        minBounds[1] = math.min(minBounds[1], v[1])
        minBounds[2] = math.min(minBounds[2], v[2])
        minBounds[3] = math.min(minBounds[3], v[3])

        maxBounds[1] = math.max(maxBounds[1], v[1])
        maxBounds[2] = math.max(maxBounds[2], v[2])
        maxBounds[3] = math.max(maxBounds[3], v[3])
    end
    local model = gltf.new(path)

    local materials=model.materials or {}

    sendMaterials(materials)
    sendTextures(basePath, model.textures)
    local triangles={}
    local lights={}

    local totalIndices=0
    local triangleData = {}
    for ii,v in pairs(model.nodes) do
        if string.find(v.name:lower(),"camera") then
            cam.pos = mirrorX(v.translation)

            cam.forward = mirrorX(quatRotate({0,0,-1}, v.rotation))
            cam.up      = mirrorX(quatRotate({0,-1,0}, v.rotation))
            cam.right   = mirrorX(quatRotate({1,0,0}, v.rotation))
            cam.fov=model.cameras[1].perspective.yfov

            goto continue
        end
        if not v.mesh then goto continue end
        local mesh = v.mesh
        local primitive = mesh.primitives[1]
        local positions = primitive.attributes.POSITION:get()
        local normals = primitive.attributes.NORMAL:get()
        local indices = primitive.indices:get()
        local uvs = primitive.attributes.TEXCOORD_0

        if uvs then
            uvs = uvs:get()
        else
            uvs = {}
            for i = 1, #positions do
                uvs[i] = {0, 0}
            end
        end

        totalIndices=totalIndices+#indices

        for i=1,#indices,3 do
            local a = mirrorX(transformPoint(positions[indices[i]+1], v))
            local b = mirrorX(transformPoint(positions[indices[i+1]+1], v))
            local c = mirrorX(transformPoint(positions[indices[i+2]+1], v))

            triangles[#triangles+1]={
                id=#triangles, 

                posA=a,
                posB=b,
                posC=c,

                center={
                    (a[1]+b[1]+c[1])/3,
                    (a[2]+b[2]+c[2])/3,
                    (a[3]+b[3]+c[3])/3
                }
            }
            local materialIndex = model:IndexOf(primitive.material)
            
            if materialIndex and primitive.material.extensions and primitive.material.extensions.KHR_materials_emissive_strength then
                local emiss = primitive.material.extensions.KHR_materials_emissive_strength.emissiveStrength
                
                table.insert(lights,#triangles)
            end
        end
        for i = 1, #indices, 3 do
            local ia = indices[i] + 1
            local ib = indices[i+1] + 1
            local ic = indices[i+2] + 1
            local verts = {
                mirrorX(transformPoint(positions[ia], v)),
                mirrorX(transformPoint(positions[ic], v)),
                mirrorX(transformPoint(positions[ib], v)),

                mirrorX(transformNormal(normals[ia], v)),
                mirrorX(transformNormal(normals[ic], v)),
                mirrorX(transformNormal(normals[ib], v)),

                uvs[ia],
                uvs[ic],
                uvs[ib]
            }
            expandBounds(verts[1])
            expandBounds(verts[2])
            expandBounds(verts[3])
            
            for _, v in ipairs(verts) do
                table.insert(triangleData, v[1])
                table.insert(triangleData, v[2])
                if v[3] then
                    table.insert(triangleData, v[3])
                end
            end

            local materialIndex = model:IndexOf(primitive.material)
            
            if materialIndex then materialIndex=materialIndex+1 else materialIndex=0 end
            table.insert(triangleData, materialIndex)
        end
        ::continue::
    end

    --[[lightsBuffer = love.graphics.newBuffer(
        "float",
        #lights+1,
        {
            shaderstorage = true
        }
    )

    lightsBuffer:setArrayData(lights)

    if #lights>0 then
        shaders.rt:send("lightsBuffer",lightsBuffer)
        shaders.rt:send("numLights",#lights)
    end]]

    local tree=buildBVH(triangles)

    triangleBuffer = love.graphics.newBuffer(
        "float",
        #triangleData+1,
        {
            shaderstorage = true
        }
    )
    
    triangleBuffer:setArrayData(triangleData)

    local nodes = {}
    local triangleIndices = {}

    flattenBVH(tree,nodes,triangleIndices)
    local bvhBuffer = love.graphics.newBuffer(
        "float",
        #nodes,
        {
            shaderstorage = true
        }
    )

    bvhBuffer:setArrayData(nodes)

    triangleIndexBuffer = love.graphics.newBuffer(
        "int32",
        #triangleIndices,
        {shaderstorage=true}
    )

    triangleIndexBuffer:setArrayData(triangleIndices)
    
    shaders.rt:send("TriangleIndices", triangleIndexBuffer)

    shaders.rt:send("bvh", bvhBuffer)

    shaders.rt:send("Triangles", triangleBuffer)
    bvhBuffer=nil
    triangleIndexBuffer=nil
    triangleBuffer=nil
    nodes=nil
    triangleIndices=nil
    collectgarbage("collect")
    --shaders.rt:send("triangleCount", totalIndices / 3)
    
end

return gltfLoader