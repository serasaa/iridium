extern float iTime;
extern vec2 iResolution;
extern float iTimeDelta;


//dont worry about that i was figuring out noise
float noise(vec2 pos) {
    return sin(iTime*pow(pos.x*iTime*iTime,pos.y)*2346815.857635*fract(iTimeDelta));
}

vec4 effect(vec4 fragColor,Image tex, vec2 fragCoord, vec2 sCoord )
{

    vec2 uv = sCoord/iResolution.xy;
    
    // wave params
    float waveFreq = 2.0;
    float waveSpeed = 1.0;
    float waveAmp = 0.2*sin(iTime*.5+uv.x*sin(iTime*1.2));
    float waveOffY = 0.5;

    
    vec3 finalCol = vec3(.4,.5,.7)/distance(0.0,uv.y+.5);
     finalCol*=1.0+Texel(tex,uv).rgb;
    float wave = waveOffY+sin((iTime*waveSpeed*1.0+abs(sin(iTime*.1)))+(uv.x*waveFreq))*waveAmp;
    
    if (uv.y>wave && uv.y<wave+.005) {
        finalCol*=vec3(1.3);
    }
    if (uv.y>wave) {
        finalCol*=vec3(1.4,1.7,1.9)*1.0+(uv.y-wave);
    }

    return vec4(finalCol,1.0);
}