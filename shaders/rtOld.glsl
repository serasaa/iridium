#pragma language glsl4
extern float iTime;
uniform float maxDist;
uniform vec3 camPos;
uniform vec3 camForward;
uniform vec3 camRight;
uniform vec3 camUp;
uniform float fov;
uniform vec2 res;
uniform float frameCount;
uniform Image canvas;

uniform int samples;
uniform int bounces;
uniform bool rendering;

uniform vec3 triangleData[1000];
uniform int triangleCount;

#define PI 3.14159265359

float hash12(vec2 p) {
    return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453123);
}

// cortesy of Coding Adventures: Ray Tracing
float rand(inout uint state)
{
    state = state * 747796405u + 2891336453u;
    uint result = ((state >> ((state >> 28u) + 4u)) ^ state) * 277803737u;
    result = (result >> 22u) ^ result;
    return float(result) / 4294967295.0;
}

// cortesy of Coding Adventures: Ray Tracing
float gaussianRand(inout uint state)
{
    // Thanks to: https://stackoverflow.com/a/6178290
    float theta = 2.0 * 3.14159265359 * rand(state);
    float rho = sqrt(-2.0 * log(rand(state)));
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

vec2 hash22(vec2 p) {
    vec3 p3 = fract(vec3(p.xyx) * vec3(.1031, .1030, .0973));
    p3 += dot(p3, p3.yzx + 33.33);
    return fract((p3.xx + p3.yz) * p3.zy);
}

vec3 getHemisphereDir(vec3 normal, inout  uint seed)
{
    vec3 randomDir = RandomDirection(seed);

    if (dot(normal,randomDir) < 0.){
        randomDir=reflect(randomDir,normal);
    }
    return randomDir;
}

struct Material {
    vec3 color;
    vec3 emissionColor;
    float roughness;
    float emissionStrength;
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

    Material material;
};

struct HitInfo {
    bool didHit;
    Material material;
    float dst;
    vec3 normal;
    vec3 hitPoint;
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

// Calculate the intersection of a ray with a triangle using Möller–Trumbore algorithm
// Thanks to: https://stackoverflow.com/a/42752998

//cortesy of Coding Adventures: Ray Tracing
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

    // Initialize hit info
    HitInfo hitInfo;
    hitInfo.didHit = determinant >= 1E-6 && dst >= 0.0 && u >= 0.0 && v >= 0.0 && w >= 0.0;
    hitInfo.hitPoint = ray.origin + ray.dir * dst;
    hitInfo.normal = normalize(tri.normalA * w + tri.normalB * u + tri.normalC * v);
    hitInfo.dst = dst;
    return hitInfo;
}
 
Triangle getTriangle(int id)
{
    int i = id * 6;

    Triangle tri;

    tri.posA = triangleData[i+0];
    tri.posB = triangleData[i+1];
    tri.posC = triangleData[i+2];

    tri.normalA = triangleData[i+3];
    tri.normalB = triangleData[i+4];
    tri.normalC = triangleData[i+5];

    return tri;
}

HitInfo calcRayHit(Ray ray) {
    
    #define ballCount 4
    Ball balls[ballCount];

    Ball ball0;
    ball0.radius=7.0;
    ball0.pos=vec3(-10.,4.0,25);
    ball0.material.color=vec3(.1,.5,.9);
    ball0.material.roughness=1.;

    Ball ball1;
    ball1.radius=120.0;
    ball1.pos=vec3(-900.,300.0,23);
    ball1.material.color=vec3(0);
    ball1.material.emissionStrength=350.0;
    ball1.material.emissionColor=vec3(1.);
    ball1.material.roughness=1.;

    Ball ball2;
    ball2.radius=5.0;
    ball2.pos=vec3(-10,3,5.);
    ball2.material.color=vec3(.95,.1,.1);
    ball2.material.roughness=1.;

    Ball ball3;
    ball3.radius=55.0;
    ball3.pos=vec3(-9.,-55,15);
    ball3.material.color=vec3(0.9,0.4,0.05);
    ball3.material.roughness=1.;

    balls[0]=ball0;
    balls[1]=ball1;
    balls[2]=ball2;
    balls[3]=ball3;

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

    for(int i = 0; i < triangleCount; i++)
    {
        Triangle tringle = getTriangle(i);
        tringle.material.color = vec3(0.8);
        tringle.material.roughness = 0;
        
        // FIX: Pass the tringle, not the undefined array!
        HitInfo curHit = RayTriangle(ray, tringle); 

        if (curHit.didHit && closestHit.didHit) {
            if (curHit.dst < closestHit.dst) {
                closestHit = curHit;
                closestHit.material = tringle.material;
            }
        }
        else if (curHit.didHit) {
            closestHit = curHit;
            closestHit.material = tringle.material;
        }
    }
    
    return closestHit;
}

vec3 tracePath(Ray ray, inout uint seed)
{

    vec3 rayCol = vec3(1.0);
    vec3 rayBrightness = vec3(0.0);
    
    vec3 skyHorizon = vec3(.5,.5,.7);
    vec3 skyZenith = vec3(.1,.2,.9);
    for (int bounce = 0; bounce < bounces; bounce++)
    {

        seed ^= uint(bounce) * 31847u;
        HitInfo result = calcRayHit(ray);

        if (result.didHit)
        {
            float bias = 0.001 * (1.0 - abs(dot(ray.dir, result.normal)));
            ray.origin = result.hitPoint + (result.normal * bias);

            vec3 specReflect = reflect(ray.dir, result.normal);
            vec3 diffReflect = getHemisphereDir(result.normal, seed);
            
            ray.dir = normalize(mix(specReflect, diffReflect,result.material.roughness*1.));

            vec3 emittedLight = result.material.emissionColor * result.material.emissionStrength;
            float lightStrength=dot(result.normal,ray.dir);

            rayBrightness += emittedLight * rayCol; 
            
            rayCol *= result.material.color*mix(1.,lightStrength*2.,result.material.roughness); 
        }
        else
        {
            //sky
            float skyBrightness =1.;
            rayBrightness += rayCol * (mix(skyHorizon, skyZenith, ray.dir.y)*skyBrightness);
            break;
        }
    }

    return rayBrightness;
}

vec3 rayTrace(vec2 uv,vec2 sCoord)
{
    vec3 finalColor = vec3(0.0);
    vec3 fTest=vec3(0.0);

    for (int i = 0; i < samples; i++)
    {
        Ray ray;

        uint rng =
        uint(sCoord.x) * 1973u ^
        uint(sCoord.y) * 9277u *
        uint(iTime+frameCount) * 26699u ^
        uint(i) * 31847u;

        float u = uv.x * 2.0 - 1.0;
        float v = uv.y * 2.0 - 1.0;

        u *= love_ScreenSize.x / love_ScreenSize.y;

        float scale = tan(fov * 0.5);

        u *= scale;
        v *= scale;

        ray.origin = camPos;
        
        ray.dir = normalize(camForward + camRight * u + camUp * v);
        finalColor += tracePath(ray, rng);
        fTest=vec3(normalize(ray.origin));
    }

    return (finalColor / float(samples)*1.);
}

vec4 effect(vec4 fragColor, Image tex, vec2 fragCoord, vec2 sCoord )
{
    vec2 pixelPos = sCoord; 
    vec2 pixelCoords = floor(fragCoord * love_ScreenSize.xy);
    
    // 2. Add 0.5 to target the dead center of the pixel
    vec2 uv = (pixelCoords + 0.5) / love_ScreenSize.xy;
    if (!rendering) {
        return vec4(Texel(canvas,uv).x,Texel(canvas,uv).y,Texel(canvas,uv).z,1);
    }

    vec3 sampl = rayTrace(uv,sCoord);
    //reinhard (uncomment to activate)
    //sampl = sampl / (sampl + 1.0);

    sampl = pow(sampl, vec3(1.0 / 2.2));
    if(frameCount <= 1.0)
    {
        return vec4(sampl,1.);
    }

    vec3 old = Texel(canvas, uv).rgb;
    return vec4(mix(old, sampl, 1. / frameCount),1.);

}