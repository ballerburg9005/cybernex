// https://www.shadertoy.com/view/ldjGzV
// shadertoy default license CC BY-NC-SA 3.0 DEED
// https://creativecommons.org/licenses/by-nc-sa/3.0/deed.en

shader_type canvas_item;

uniform sampler2D iChannel0;
uniform sampler2D iChannel1;

float noise(vec2 p)
{
	float shit = TIME*60.0;
	shit = shit - 1.0 * floor(shit/1.0);
	float s = texture(iChannel1,vec2(1.,2.*cos(shit))*shit*8. + p*1.).x;
	s *= s;
	return s;
}

float onOff(float a, float b, float c)
{
	return step(c, sin((0.5*TIME) + a*cos((0.5*TIME)*b)));
}

float ramp(float y, float start, float end)
{
	float inside = step(start,y) - step(end,y);
	float fact = (y-start)/(end-start)*inside;
	return (1.-fact) * inside;
	
}

float stripes(vec2 uv)
{
	
	float noi = noise(uv*vec2(0.5,1.) + vec2(1.,3.));
	return ramp(mod(uv.y*4. + (0.5*TIME)/2.+sin((0.5*TIME) + sin((0.5*TIME)*0.63)),1.),0.5,0.6)*noi;
}

vec3 getVideo(vec2 uv)
{
	vec2 look = uv;
	float window = 1./(1.+20.*(look.y-mod((0.5*TIME)/4.,1.))*(look.y-mod((0.5*TIME)/4.,1.)));
	look.x = look.x + sin(look.y*1.2 + (0.5*TIME))/50.*onOff(4.,4.,.3)*(1.+cos((0.5*TIME)*120.))*window;
	float vShift = 0.4*onOff(2.,3.,.9)*(sin((0.5*TIME))*sin((0.5*TIME)*2.) + 
										 (0.5 + 0.1*sin((0.5*TIME)*2.)*cos((0.5*TIME))));
	look.y = mod(look.y + vShift*0.02, 1.0);
	vec3 video = vec3(texture(iChannel0,look).x, texture(iChannel0,look).y, texture(iChannel0,look).z);
	return video;
}

vec2 screenDistort(vec2 uv)
{
	uv -= vec2(.5,.9);
	uv = uv*1.2*(1./1.2+2.*uv.x*uv.x*uv.y*uv.y);
	uv += vec2(.5,.9);
	return uv;
}

void fragment() {
	vec2 iResolution = vec2(1.0, 1.0);
	vec2 fragCoord = UV; //fragCoord.y = 1.0 - UV.y;
 
	vec2 uv = fragCoord.xy / iResolution.xy;
 
	vec2 uv2 = (fragCoord * 2.0 - iResolution.xy) / iResolution.y;
	vec2 uv0 = uv2;
	
	uv = screenDistort(uv);
	vec3 video = getVideo(uv);
	float vigAmt = 3.+.3*sin((0.5*TIME) + 5.*cos((0.5*TIME)*5.));
	float vignette = (1.-vigAmt*(uv.y-.5)*(uv.y-.5))*(1.-vigAmt*(uv.x-.5)*(uv.x-.5));
	
	video += stripes(uv2);
	video += noise(uv2*2.)/2.;
	video *= vignette;
	video *= (12.+mod(uv.y*30.+(0.5*TIME),1.))/13.;
	
	COLOR = vec4(video,1.0);
}