#define PI 3.14159265
extern vec2 screenSize;
extern float time;

float rect(vec2 uv, vec2 center, vec2 size, float blur) {
    vec2 d = abs(uv - center) - size * 0.5;
    float inside = max(d.x, d.y);
    return 1.0 - smoothstep(0.0, blur, inside);
}

vec2 warp(vec2 uv, float warp_amount){
    vec2 delta = uv - 0.5;
    float delta2 = dot(delta.xy, delta.xy);
    float delta4 = delta2 / 2.0;
    float delta_offset = delta4 * warp_amount;
    return uv + delta * delta_offset;
}

vec4 effect(vec4 color, Image tex, vec2 texcoord, vec2 coord) {
    vec2 flat_uv = coord.xy / screenSize.xy;
    float intensity = .00005;
    
    vec2 uv = clamp(warp(flat_uv, intensity / 10.0), vec2(0.0), vec2(1.1));
    
    float lineSpeed = 0.1;
    vec4 finalColor = color;
    finalColor -= vec4(rect(uv, vec2(0.0, (tan(time * lineSpeed))), vec2(5.0, 0.1), 0.05) * .2);

    vec2 crtCoord = uv * screenSize; 

    float scanline = 0.85 + 0.15 * cos(crtCoord.y * PI);
    finalColor.rgb *= scanline;

    float phosphorWidth = 3.0; 
    float cellWidth = phosphorWidth * 3.0;
    
    float omega = (2.0 * PI) / cellWidth;
    
    vec3 mask;
    mask.r = 0.5 + 0.5 * cos(crtCoord.x * omega);
    mask.g = 0.5 + 0.5 * cos((crtCoord.x - phosphorWidth) * omega);
    mask.b = 0.5 + 0.5 * cos((crtCoord.x - phosphorWidth * 2.0) * omega);

    float phosphorHeight = 5.0;
    float verticalMask = 0.8 + 0.2 * cos(crtCoord.y * (2.0 * PI / phosphorHeight));
    
    finalColor.rgb *= mask * verticalMask;
    
    vec4 texColor = Texel(tex, uv);
    
    finalColor *= texColor * 1.6; 
    
    vec2 center_uv = uv * 2.0 - 1.0; 
    
    vec2 size = vec2(.98); 
    float radius = 0;   

    vec2 q = abs(center_uv) - size + radius;
    float dist = min(max(q.x, q.y), 0.0) + length(max(q, 0.0)) - radius;

    float bezel = 1.0 - smoothstep(0.0, 0.02, dist);
    finalColor *= bezel;
    
    return mix(texColor, finalColor, clamp(intensity, 0.0, 1.0));
}