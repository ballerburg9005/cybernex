// https://www.shadertoy.com/view/4dBGzK
// shadertoy default license CC BY-NC-SA 3.0 DEED
// https://creativecommons.org/licenses/by-nc-sa/3.0/deed.en

shader_type canvas_item;

uniform sampler2D iChannel0: hint_screen_texture;

highp float rand(vec2 co)
{
    highp float a = 12.9898;
    highp float b = 78.233;
    highp float c = 43758.5453;
    highp float dt= dot(co.xy ,vec2(a,b));
    highp float sn= mod(dt,3.14);
    return fract(sin(sn) * c);
}

void fragment()
{
	vec2 iResolution = vec2(1.0, 1.0);
	vec2 fragCoord = UV; //fragCoord.y = 1.0 - UV.y;
 
	vec2 uv = fragCoord.xy / iResolution.xy;
	// Flip Y Axis
	uv.y = -uv.y;
	
	uv = SCREEN_UV;
	
	highp float magnitude = 0.000009;
	
	
	// Set up offset
	vec2 offsetRedUV = uv;
	offsetRedUV.x = uv.x + rand(vec2(TIME*0.03,uv.y*0.42)) * 0.0008;
	offsetRedUV.x += sin(rand(vec2(TIME*0.2, uv.y)))*magnitude;
	
	vec2 offsetGreenUV = uv;
	offsetGreenUV.x = uv.x + rand(vec2(TIME*0.004,uv.y*0.002)) * 0.0016;
	offsetGreenUV.x += sin(TIME*9.0)*magnitude;
	
	vec2 offsetBlueUV = uv;
	offsetBlueUV.x = uv.y;
	offsetBlueUV.x += rand(vec2(cos(TIME*0.01),sin(uv.y)));
	
	// Load Texture
	float r = texture(iChannel0, offsetRedUV).r;
	float g = texture(iChannel0, offsetGreenUV).g;
	float b = texture(iChannel0, uv).b;
	
	COLOR = vec4(r,g,b,0.5);
	
}