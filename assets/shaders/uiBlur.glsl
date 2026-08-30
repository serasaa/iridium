extern Image bgCanvas;
extern vec2 screenSize;
extern vec2 snapshotSize;
extern float radius;

vec4 effect(vec4 color, Image texture, vec2 texture_coords, vec2 screen_coords) {
    float Pi = 6.28318530718; 
    
    float Directions = 16.0;
    float Quality = 4.0; 
    float Size = radius; 
   
    vec2 Radius = Size/screenSize.xy;
    
    vec2 uv = screen_coords/screenSize.xy;
    vec4 Color = Texel(bgCanvas, uv);
    
    for( float d=0.0; d<Pi; d+=Pi/Directions)
    {
		for(float i=1.0/Quality; i<=1.0; i+=1.0/Quality)
        {
			Color += Texel(bgCanvas, uv+vec2(cos(d),sin(d))*Radius*i);		
        }
    }
    
    Color /= Quality * Directions - 15.0;
    return Color;
}