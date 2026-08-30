#pragma language glsl4

layout(local_size_x = 8, local_size_y = 8) in;
layout(rgba32f) writeonly uniform image2D OutputImage;

layout(rgba32f) writeonly uniform image2D depthBuffer;

layout(std430) readonly buffer Triangles
{
    float data[];
};

layout(std430) readonly buffer MaterialBuffer
{
    float materials[];
};

layout(std430) readonly buffer bvh
{
    float bvhNodes[];
};

layout(std430) readonly buffer TriangleIndices
{
    int triangleIndices[];
};

uniform sampler2D images[96];

extern float iTime;
uniform float maxDist;
uniform vec3 camPos;
uniform vec3 camForward;
uniform vec3 camRight;
uniform vec3 camUp;
uniform float fov;
uniform vec2 res;
uniform float frameCount;
uniform Image InputImage;

uniform float focusDistance;

uniform int samples;
uniform int bounces;
uniform bool rendering;

uniform vec3 meshMin;
uniform vec3 meshMax;

uniform int triangleCount;
uniform Image hdri;

uniform vec2 rtRes;
layout(rgba8, binding = 0) uniform readonly image2D bNoise; 

#define PI 3.14159265359


// cortesy of Coding Adventures: Ray Tracing
float rand(inout uint state)
{
    state = state * 747796405u + 2891336453u;
    uint result = ((state >> ((state >> 28u) + 4u)) ^ state) * 277803737u;
    result = (result >> 22u) ^ result;
    return float(result) / 4294967295.0;
}

vec2 getR2(vec2 pixel, float frame) {
    vec2 alpha = vec2(0.7548776662466927, 0.5698402909980532);
    
    return fract(alpha * (pixel.x + pixel.y * rtRes.x) + alpha * frame);
}

// cortesy of Coding Adventures: Ray Tracing
float gaussianRand(inout uint state)
{
    // Thanks to: https://stackoverflow.com/a/6178290
    float theta = 2.0 * 3.14159265359 * rand(state);
    float r = max(rand(state), 1e-8);
    float rho = sqrt(-2.0 * log(r));
    return rho * cos(theta);
}

// cortesy of Coding Adventures: Ray Tracing
vec3 RandomDirection(inout uint state)
{
    // Thanks to: https://math.stackexchange.com/a/1585996
    float x = gaussianRand(state);
    float y = gaussianRand(state);
    float z = gaussianRand(state);
    return normalize(vec3(x, y, z));
}

vec2 RandomPointinCircle(inout uint state){
    float angle = rand(state)*2*PI;
    vec2 pointOnCircle = vec2(cos(angle),sin(angle));
    return pointOnCircle*sqrt(rand(state));
}

vec3 getHemisphereDir(vec3 normal, inout  uint seed)
{
    vec3 randomDir = RandomDirection(seed);

    if (dot(normal,randomDir) < 0.){
        randomDir=reflect(randomDir,normal);
    }
    return randomDir;
}

vec3 getCosineWeightedHemisphere(vec3 normal, inout uint seed) {
    float r1 = rand(seed);
    float r2 = rand(seed);
    
    float z = sqrt(1.0 - r2);
    float phi = 2.0 * PI * r1;
    float x = cos(phi) * sqrt(r2);
    float y = sin(phi) * sqrt(r2);
    
    // Create a tangent space matrix
    vec3 up = abs(normal.z) < 0.999 ? vec3(0.0, 0.0, 1.0) : vec3(1.0, 0.0, 0.0);

    vec3 tangent = cross(up, normal);

    tangent = normalize(tangent);
    vec3 bitangent = cross(normal, tangent);
    
    return normalize(tangent * x + bitangent * y + normal * z);
}

struct Material {
    vec3 color;
    vec3 emissionColor;
    float roughness;

    float type;
    float ior;

    vec3 clearCoatColor;
    float metalness;

    float emissionStrength;
    int textureId;
};

struct Ray {
    vec3 origin;
    vec3 dir;
    float dist;
};

struct Ball {
    vec3 pos;
    float radius;

    Material material;
};

struct Triangle {
    vec3 posA;
    vec3 posB;
    vec3 posC;

    vec3 normalA;
    vec3 normalB;
    vec3 normalC;

    vec2 uvA;
    vec2 uvB;
    vec2 uvC;

    int materialID;
};

struct Light {
    int triID;
};

uniform int lights[];
uniform int numLights;

struct BVHNode
{
    vec3 minBounds;
    int left;

    vec3 maxBounds;
    int right;

    int triStart;
    int triCount;
};

struct HitInfo {
    bool didHit;
    bool isBackface;
    Material material;
    float dst;
    vec3 normal;
    vec3 hitPoint;
    vec2 uv;
};


//adapted from Coding Adventures: Ray Tracing by Sebastian Lague
HitInfo raySphere(Ray ray, Ball ball) {
    HitInfo hitInfo;

    vec3 spherePos = ball.pos;
    float sphereRadius = ball.radius;

    vec3 offsetRayOrigin=ray.origin - spherePos;

    hitInfo.didHit=false;

    float a = dot(ray.dir, ray.dir);
    float b = 2. * dot(offsetRayOrigin, ray.dir);
    float c = dot(offsetRayOrigin, offsetRayOrigin) - sphereRadius*sphereRadius;

    float discriminant = b*b-4.*a*c;

    if (discriminant>=0.) {
        float dst = (-b - sqrt(discriminant)) / (2. * a);

        if (dst >= 0.) {
            hitInfo.didHit=true;
            hitInfo.dst=dst;
            hitInfo.hitPoint = ray.origin + ray.dir * dst;
            hitInfo.normal = normalize(hitInfo.hitPoint - spherePos);
        }
    }
    return hitInfo;
}

float rayBox(Ray ray, vec3 boxMin, vec3 boxMax, float maxDst)
{
    vec3 invDir = 1.0 / ray.dir;

    vec3 t0 = (boxMin - ray.origin) * invDir;
    vec3 t1 = (boxMax - ray.origin) * invDir;

    vec3 tmin = min(t0, t1);
    vec3 tmax = max(t0, t1);

    float nearT = max(max(tmin.x, tmin.y), tmin.z);
    float farT  = min(min(tmax.x, tmax.y), tmax.z);

    float boxDist = max(nearT,0.0);

    return (farT >= boxDist && boxDist < maxDst) ? boxDist : 1e30;
}

// Calculate the intersection of a ray with a triangle using Möller–Trumbore algorithm
// Thanks to: https://stackoverflow.com/a/42752998

// cortesy of Coding Adventures: Ray Tracing
HitInfo RayTriangle(Ray ray, Triangle tri)
{
    vec3 edgeAB = tri.posB - tri.posA;
    vec3 edgeAC = tri.posC - tri.posA;
    vec3 normalVector = cross(edgeAB, edgeAC);
    vec3 ao = ray.origin - tri.posA;
    vec3 dao = cross(ao, ray.dir);

    float determinant = -dot(ray.dir, normalVector);
    float invDet = 1.0 / determinant;

    // Calculate dst to triangle & barycentric coordinates of intersection point
    float dst = dot(ao, normalVector) * invDet;
    float u = dot(edgeAC, dao) * invDet;
    float v = -dot(edgeAB, dao) * invDet;
    float w = 1.0 - u - v;

    vec2 uv = tri.uvA * w + tri.uvB * u + tri.uvC * v;

    // Initialize hit info
    HitInfo hitInfo;
    hitInfo.uv=uv;
    hitInfo.didHit = abs(determinant) >= 1E-6 && dst > 0.0001 && u >= 0.0 && v >= 0.0 && w >= 0.0;
    hitInfo.isBackface = determinant < 0.0;
    hitInfo.hitPoint = ray.origin + ray.dir * dst;
    hitInfo.normal = normalize(tri.normalA * w + tri.normalB * u + tri.normalC * v);
    if (hitInfo.isBackface) {
        hitInfo.normal = -hitInfo.normal;
    }
    hitInfo.dst = dst;
    return hitInfo;
}
 
Triangle getTriangle(int id)
{
    int i = id * 25;

    Triangle tri;

    tri.posA = vec3(data[i+0], data[i+1], data[i+2]);
    tri.posB = vec3(data[i+3], data[i+4], data[i+5]);
    tri.posC = vec3(data[i+6], data[i+7], data[i+8]);

    tri.normalA = vec3(data[i+9], data[i+10], data[i+11]);
    tri.normalB = vec3(data[i+12], data[i+13], data[i+14]);
    tri.normalC = vec3(data[i+15], data[i+16], data[i+17]);

    tri.uvA = vec2(data[i+18], data[i+19]);
    tri.uvB = vec2(data[i+20], data[i+21]);
    tri.uvC = vec2(data[i+22], data[i+23]);

    tri.materialID = int(data[i+24]);

    return tri;
}

#define BVH_NODE_SIZE 12

BVHNode getNode(int id)
{
    int i = id * BVH_NODE_SIZE;

    BVHNode node;

    node.minBounds = vec3(
        bvhNodes[i+0],
        bvhNodes[i+1],
        bvhNodes[i+2]
    );

    node.left = int(bvhNodes[i+3]);

    node.maxBounds = vec3(
        bvhNodes[i+4],
        bvhNodes[i+5],
        bvhNodes[i+6]
    );

    node.right = int(bvhNodes[i+7]);

    node.triStart = int(bvhNodes[i+8]);
    node.triCount = int(bvhNodes[i+9]);

    return node;
}

#define MATERIAL_SIZE 15

Material getMaterial(int id)
{
    int i = id * MATERIAL_SIZE;

    Material mat;

    mat.color = vec3(
        materials[i+0],
        materials[i+1],
        materials[i+2]
    );

    mat.emissionColor = vec3(
        materials[i+3],
        materials[i+4],
        materials[i+5]
    );

    mat.roughness = materials[i+6];

    mat.clearCoatColor = vec3(
        materials[i+7],
        materials[i+8],
        materials[i+9]
    );

    mat.metalness = materials[i+10];

    mat.emissionStrength = materials[i+11];

    mat.textureId = int(materials[i+12]);
    mat.type = materials[i+13];
    mat.ior = materials[i+14];

    return mat;
}

HitInfo traverseBVH(Ray ray)
{
    HitInfo closestHit;
    closestHit.didHit = false;
    closestHit.dst = 18963231.65831; 

    int stack[32];
    int stackPtr = 0;

    stack[stackPtr++] = 0; // root node

    while(stackPtr > 0)
    {
        int nodeID = stack[--stackPtr];
        BVHNode node = getNode(nodeID);

        // leaf
        if(node.triCount > 0)
        {
            for(int i = 0; i < node.triCount; i++)
            {
                int triID = triangleIndices[node.triStart+i];
                Triangle triangle = getTriangle(triID);
                
                HitInfo curHit = RayTriangle(ray, triangle);

                if(curHit.didHit && curHit.dst < closestHit.dst)
                {
                    closestHit = curHit; 
                    
                    if(triangle.materialID == 0)
                    {
                        Material mat = {
                            vec3(.8),
                            vec3(0.),
                            .5,

                            int(0),
                            1.5,

                            vec3(1.),
                            0,

                            0.,
                            0,
                        };
                        closestHit.material = mat;
                    }
                    else
                    {
                        closestHit.material = getMaterial(triangle.materialID-1);
                    }
                }
            }
        }
        // branch
        else
        {
            BVHNode childLeft = getNode(node.left);
            BVHNode childRight = getNode(node.right);

            float distLeft = rayBox(ray, childLeft.minBounds, childLeft.maxBounds, closestHit.dst);
            float distRight = rayBox(ray, childRight.minBounds, childRight.maxBounds, closestHit.dst);

            if (distLeft > distRight){
                if (distLeft < closestHit.dst) stack[stackPtr++] = node.left;
                if (distRight < closestHit.dst) stack[stackPtr++] = node.right;
            }
            else{
                if (distRight < closestHit.dst) stack[stackPtr++] = node.right;
                if (distLeft < closestHit.dst) stack[stackPtr++] = node.left;
            }
        }
    }

    return closestHit;
}

HitInfo calcRayHit(Ray ray) {
    
    #define ballCount 4
    Ball balls[ballCount];

   /* Ball ball0;
    ball0.radius=7.0;
    ball0.pos=vec3(-10.,4.0,25);
    ball0.material.color=vec3(.1,.5,.9);
    ball0.material.roughness=1.;

    Ball ball1;
    ball1.radius=120.0;
    ball1.pos=vec3(-900.,300.0,23);
    ball1.material.color=vec3(0);
    ball1.material.emissionStrength=500.0;
    ball1.material.emissionColor=vec3(1.);
    ball1.material.roughness=1.;

    Ball ball2;
    ball2.radius=5.0;
    ball2.pos=vec3(-10,3,5.);
    ball2.material.color=vec3(1,1,1);
    ball2.material.roughness=1.;
    ball2.material.type=1;

    Ball ball3;
    ball3.radius=55.0;
    ball3.pos=vec3(-9.,-55,15);
    ball3.material.color=vec3(0.9,0.4,0.05);
    ball3.material.roughness=1.;

    balls[0]=ball0;
    balls[1]=ball1;
    balls[2]=ball2;
    balls[3]=ball3;*/

    HitInfo closestHit;
    closestHit.didHit=false;

    for (int i = 0; i<ballCount; i++){
        Ball ball = balls[i];
        HitInfo curHit = raySphere(ray, ball);

        if (curHit.didHit && closestHit.didHit) {
            if (curHit.dst < closestHit.dst) {
                closestHit = curHit;
                closestHit.material=ball.material;
            }
        }
        else if (curHit.didHit) {
            closestHit = curHit;
            closestHit.material=ball.material;
        }
    }

    HitInfo meshHit = traverseBVH(ray);

    if(meshHit.didHit && (!closestHit.didHit || meshHit.dst < closestHit.dst))
    {
        closestHit = meshHit;
    }

    
    return closestHit;
}

// cortesy from seblague (https://github.com/SebLague/Ray-Tracing/blob/main/Assets/Scripts/Tracer/RayCommon.hlsl)
float CalculateReflectance(vec3 inDir, vec3 normal, float iorA, float iorB)
{
    float refractRatio = iorA / iorB;
    float cosAngleIn = -dot(inDir, normal);
    float sinSqrAngleOfRefraction = refractRatio * refractRatio * (1 - cosAngleIn * cosAngleIn);
    if (sinSqrAngleOfRefraction >= 1) return 1; // Ray is fully reflected, no refraction occurs

    float cosAngleOfRefraction = sqrt(1 - sinSqrAngleOfRefraction);
    float denominatorPerpendicular = iorA * cosAngleIn + iorB * cosAngleOfRefraction;
    float denominatorParallel = iorA * cosAngleIn + iorB * cosAngleOfRefraction;

    if (min(denominatorPerpendicular, denominatorParallel) < 1E-8) return 1;

    // Perpendicular polarization
    float rPerpendicular = (iorA * cosAngleIn - iorB * cosAngleOfRefraction) / denominatorPerpendicular;
    rPerpendicular *= rPerpendicular;
    // Parallel polarization
    float rParallel = (iorB * cosAngleIn - iorA * cosAngleOfRefraction) / denominatorParallel;
    rParallel *= rParallel;

    // Return the average of the perpendicular and parallel polarizations
    return (rPerpendicular + rParallel) / 2;
}


vec3 tracePath(Ray ray, inout uint seed, vec2 suv)
{

    vec3 rayCol = vec3(1.0);
    vec3 rayBrightness = vec3(0.0);

    //just so the lights thingymabob isnt demolished by the compiler
    rayCol+=lights[0]*(1e-48+numLights*1e-48);
    
    vec3 skyHorizon = vec3(.5,.5,.7);
    vec3 skyZenith = vec3(.1,.2,.9);
    for (int bounce = 0; bounce <= bounces; bounce++)
    {

        seed ^= uint(bounce) * 31847u + uint(fract(iTime));
        HitInfo result = calcRayHit(ray);

        if (result.didHit)
        { 

            //depth map shit
            if (bounce == 0) {
                imageStore(depthBuffer,ivec2(gl_GlobalInvocationID.xy),vec4(vec3(result.dst),1.));
            }
            
            //common material stuff
            if (result.material.textureId>0) {
                vec2 uv = result.uv;
                int matId=result.material.textureId-1;
                
                vec3 finalCol = pow(Texel(images[matId],mod(uv,vec2(1.))).rgb,vec3(2.2));
                result.material.color = finalCol;
                result.material.emissionColor = finalCol;
            }
            
            if (result.material.roughness>1) {
                vec3 roughMap = Texel(images[int(result.material.roughness-3)],result.uv).rgb;
                result.material.roughness=roughMap.g;
                result.material.metalness=roughMap.b;
            }

            if (result.material.type>=3){
                result.material.type=Texel(images[int(result.material.type-3)],result.uv).r;
            }

            vec3 emittedLight = result.material.emissionColor * result.material.emissionStrength;
            rayBrightness += emittedLight * rayCol; 

            // dielectric shit
            if (rand(seed) > result.material.type) {
                float cosTheta = clamp(dot(-ray.dir, result.normal), 0.0, 1.0);
                

                float ior = pow((result.material.ior - 1.0) / (result.material.ior + 1.0), 2.0);
                vec3 f0 = mix(vec3(ior), result.material.color, result.material.metalness);
                
                vec3 F = f0 + (1.0 - f0) * pow(1.0 - cosTheta, 5.0);
                float specChance = (F.r + F.g + F.b) / 3.0;
                
                float bias = 0.001; 
                ray.origin = result.hitPoint + (result.normal * bias);

                if (rand(seed) < specChance) {
                    vec3 specReflect = reflect(ray.dir, result.normal);
                    
                    float alpha = result.material.roughness * result.material.roughness;
                    
                    vec3 diffReflect = getCosineWeightedHemisphere(specReflect, seed);
                    ray.dir = normalize(mix(specReflect, diffReflect, alpha));
                    rayCol *= (F / specChance); 
                    
                } else {
                    vec3 diffuseColor = result.material.color * (1.0 - result.material.metalness);
                    
                    ray.dir = getCosineWeightedHemisphere(result.normal, seed);
                    rayCol *= diffuseColor * ((vec3(1.0) - F) / (1.0 - specChance));
                }
            }

            else {
                float ior = result.material.ior;

                float cosTheta = clamp(-dot(ray.dir, result.normal), 0.0, 1.0);

                float iorCurrent = result.isBackface ? ior : 1.0;
                float iorNext = result.isBackface ? 1.0 : ior;
                float fIor = iorCurrent / iorNext;


                float reflectChance = CalculateReflectance(ray.dir,result.normal,iorCurrent,iorNext);

                vec3 refractDir = refract(ray.dir, result.normal, fIor);

                vec3 specReflect = reflect(ray.dir, result.normal);
                vec3 diffReflect = getCosineWeightedHemisphere(specReflect, seed);

                bool isTIR = (length(refractDir) < 0.001);

                if (rand(seed) <= reflectChance) {
                    ray.dir = mix(specReflect,diffReflect,result.material.roughness);
                } else {
                    ray.dir = mix(refractDir,-diffReflect,result.material.roughness);
                }

                float epsilon = 0.001;
                ray.origin = result.hitPoint + result.normal * (sign(dot(result.normal, ray.dir)) * epsilon);
                rayCol*=result.material.color;
            }

            //material 2 is thin glass
            if (result.material.type == 2) {
                float ior = result.material.ior;
                float bias = 0.005 * (1.0 - abs(dot(ray.dir, result.normal)));

                float iorCurrent = result.isBackface ? ior : 1.0;
                float iorNext = result.isBackface ? 1.0 : ior;
                float fIor = iorCurrent / iorNext;

                float reflectChance = CalculateReflectance(ray.dir,result.normal,iorCurrent,iorNext);

                if(rand(seed) < reflectChance)
                {  
                    ray.dir = reflect(ray.dir, result.normal);
                    ray.origin = result.hitPoint + (result.normal * bias);
                }
                else
                {
                    rayCol *= result.material.color;
                    ray.origin = result.hitPoint - (result.normal * bias);
                }
            }
        }
        else
        {
            //sky
            float skyBrightness =1.;
            vec3 d = normalize(ray.dir);

            float u = -atan(d.z, d.x) / (2.0 * PI) + 0.5;
            float v = acos(clamp(d.y, -1.0, 1.0)) / PI;

            rayBrightness += rayCol * Texel(hdri,vec2(u,v)).rgb*skyBrightness; //* (mix(skyHorizon, skyZenith, ray.dir.y)*skyBrightness);
            break;
        }
        
    } 

    return rayBrightness;
}

vec3 rayTrace(vec2 uv, vec2 sCoord)
{
    vec3 finalColor = vec3(0.0);

    for (int i = 0; i < samples; i++)
    {
        Ray ray;

        ivec2 texSize = imageSize(bNoise);
        int offsetX = int(frameCount * 17.0) % texSize.x;
        int offsetY = int(frameCount * 13.0) % texSize.y;
        
        ivec2 bnCoord = ivec2(int(sCoord.x) + offsetX, int(sCoord.y) + offsetY) % texSize;
        vec4 bn = imageLoad(bNoise, bnCoord);

        uint rng = 
            uint(sCoord.x + 200.0) * 1973u ^ 
            uint(sCoord.y + 200.0) * 9277u ^ 
            floatBitsToUint(bn.x+iTime) ^ 
            uint(frameCount + float(i)) * 26699u;

        float u = uv.x * 2.0 - 1.0;
        float v = uv.y * 2.0 - 1.0;

        u *= rtRes.x / rtRes.y;

        float scale = tan(fov * 0.5);

        u *= scale;
        v *= scale;

        float aaAmount = 2.5*scale;

        float aaX = rand(rng) - 0.5;
        float aaY = rand(rng) - 0.5;

        float uJittered = u + aaX * aaAmount / rtRes.x;
        float vJittered = v + aaY * aaAmount / rtRes.y;

        vec3 baseDir = normalize(
            camForward +
            camRight * uJittered +
            camUp * vJittered
        );

        vec3 focalPoint = camPos + baseDir * focusDistance;

        float r1 = rand(rng);
        float r2 = rand(rng);

        float angle = r1 * 2.0 * PI;
        float radius = pow(r2, 0.4);

        vec2 disk = vec2(cos(angle), sin(angle)) * radius;

        float apertureRadius = (1.0 / 6.3) * scale;

        ray.origin =
            camPos +
            camRight * disk.x * apertureRadius +
            camUp * disk.y * apertureRadius;

        ray.dir = normalize(focalPoint - ray.origin);
        
        finalColor += tracePath(ray, rng, uv);
    }

    return finalColor / float(samples);
}
void computemain()
{
    ivec2 pixel = ivec2(gl_GlobalInvocationID.xy);
    vec2 pixelPos = pixel; 

    vec2 uv = (vec2(pixel) + 0.5) / rtRes;

    if (!rendering) {
        imageStore(OutputImage,pixel,vec4(Texel(InputImage, uv).rgb,1));
        return;
    }

    vec3 sampl = rayTrace(uv,pixel);
    //reinhard (uncomment to activate)
    //sampl = sampl / (sampl + 1.0);

    //sampl = filmic(sampl);
    
    if (frameCount <= 1.0)
    {
        imageStore(OutputImage, pixel, vec4(sampl, 1.0));
        return;
    }

    vec3 imageDebug = Texel(images[int(uv*5)],uv).rgb;

    vec3 old = mix(Texel(InputImage, uv).rgb,imageDebug,0.);
    imageStore(OutputImage,pixel,vec4(mix(old, sampl, 1./float(frameCount)),1.));

}