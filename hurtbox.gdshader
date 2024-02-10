shader_type canvas_item;

uniform float mouseSize = 0.75;
uniform float smoothObjectPadding = 0.66;
uniform float alpha = 0.0;
uniform sampler2D screen_texture : hint_screen_texture, repeat_disable, filter_nearest;

void fragment()
{
	vec2 iResolution = vec2(1.0, 1.0); //1.0/SCREEN_PIXEL_SIZE; //vec2(1.0, 1.0);
	vec2 fragCoord = UV; //fragCoord.y = 1.0 - UV.y;
 
    vec2 uv = fragCoord.xy / iResolution.xy;
    vec3 color = textureLod(screen_texture, SCREEN_UV, 0.0).rgb;
	vec3 blurColor = vec3(0.6,0.0,0.0);

    float aspectRatio = iResolution.x / iResolution.y;
    vec2 objectCenter = vec2(0.5,0.5);

    vec2 v = uv - objectCenter;
    v.x = v.x; // * aspectRatio;
    float size = mouseSize;
    float smoothSize = size * smoothObjectPadding;
    float circleMix = smoothstep(size,size - smoothSize, length(v));
    blurColor.rgb = mix(blurColor.rgb, color.rgb, circleMix);

    COLOR = vec4(blurColor, alpha);
}