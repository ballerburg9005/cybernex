// https://www.shadertoy.com/view/MdVXzw
// shadertoy default license CC BY-NC-SA 3.0 DEED
// https://creativecommons.org/licenses/by-nc-sa/3.0/deed.en

shader_type canvas_item;

uniform float SCALE = 1.0;

const vec3 bgColor = vec3(0.01, 0.16, 0.42);
const vec3 rectColor = vec3(0.01, 0.26, 0.57);

//noise background
const float noiseIntensity = 2.8;
const float noiseDefinition = 0.6;
const vec2 glowPos = vec2(-2., 0.);

//rectangles
const float total = 60.;//number of rectangles
const float minSize = 0.03;//rectangle min size
const float maxSize = 0.08-minSize;//rectangle max size
const float yDistribution = 0.5;


float random(vec2 co){
    return fract(sin(dot(co.xy ,vec2(12.9898,78.233))) * 43758.5453);
}

float noise( in vec2 p )
{
    p*=noiseIntensity;
    vec2 i = floor( p );
    vec2 f = fract( p );
	vec2 u = f*f*(3.0-2.0*f);
    return mix( mix( random( i + vec2(0.0,0.0) ), 
                     random( i + vec2(1.0,0.0) ), u.x),
                mix( random( i + vec2(0.0,1.0) ), 
                     random( i + vec2(1.0,1.0) ), u.x), u.y);
}

float fbm( in vec2 uv )
{	
	uv *= 5.0;
    mat2 m = mat2( vec2(1.6,  1.2), vec2(-1.2,  1.6));
    float f  = 0.5000*noise( uv ); uv = m*uv;
    f += 0.2500*noise( uv ); uv = m*uv;
    f += 0.1250*noise( uv ); uv = m*uv;
    f += 0.0625*noise( uv ); uv = m*uv;
    
	f = 0.5 + 0.5*f;
    return f;
}

vec3 bg(vec2 uv )
{
    float velocity = (0.2*TIME)/1.6;
    float intensity = sin(uv.x*3.+velocity*2.)*1.1+1.5;
    uv.y -= 2.;
    vec2 bp = uv+glowPos;
    uv *= noiseDefinition;

    //ripple
    float rb = fbm(vec2(uv.x*.5-velocity*.03, uv.y))*.1;
    //rb = sqrt(rb); 
    uv += rb;

    //coloring
    float rz = fbm(uv*.9+vec2(velocity*.35, 0.0));
    rz *= dot(bp*intensity,bp)+1.2;

    //bazooca line
    //rz *= sin(uv.x*.5+velocity*.8);


    vec3 col = bgColor/(.1-rz);
    return sqrt(abs(col));
}


float rectangle(vec2 uv, vec2 pos, float width, float height, float blur) {
    
    pos = (vec2(width, height) + .01)/2. - abs(uv - pos);
    pos = smoothstep(0., blur , pos);
    return pos.x * pos.y; 
   
}

mat2 rotate2d(float _angle){
    return mat2(vec2(cos(_angle),-sin(_angle)),
                vec2(sin(_angle),cos(_angle)));
}

void fragment()
{
	vec2 iResolution = vec2(1.0, 1.0);
	vec2 fragCoord = UV; fragCoord.y = 1.0 - UV.y;
 
	vec2 uv = fragCoord.xy / iResolution.xy * 2. - 1.;
    uv.x *= iResolution.x/iResolution.y;
	
    uv = vec2(uv.y*SCALE, uv.x);
	
    //bg
    vec3 color = bg(uv)*(2.-abs(uv.y*2.));
    
    //rectangles
    float velX = -(0.2*TIME)/8.;
    float velY = (0.2*TIME)/10.;
    for(float i=0.; i<total; i++){
        float index = i/total;
        float rnd = random(vec2(index));
        vec3 pos = vec3(0, 0., 0.);
        pos.x = fract(velX*rnd+index)*4.-2.0;
        pos.y = sin(index*rnd*1000.+velY) * yDistribution;
        pos.z = maxSize*rnd+minSize;
        vec2 uvRot = uv - pos.xy + pos.z/2.;
    	uvRot = rotate2d( i+(0.2*TIME)/2. ) * uvRot;
        uvRot += pos.xy+pos.z/2.;
        float rect = rectangle(uvRot, pos.xy, pos.z, pos.z, (maxSize+minSize-pos.z)/2.);
	    color += rectColor * rect * pos.z/maxSize;
    }
    
	COLOR = vec4(color*0.2, 1.0)+0.1;
}