#pragma header

// Emulates Godot 2D PointLight2D lighting for one sprite (see stages/alley.lua).
//   BgLight (Mix) : base * ((1 - a) + a * lightRGB * energy)
//   other lights  : base * (1 + sum(lightTexture * colour * energy))   (Add)
// All lights are positioned in "light space" = scroll-factor-1 world pixels.

uniform sampler2D bgTex;    // darkness_gradient
uniform sampler2D poleTex;  // post_light_gradient
uniform sampler2D coneTex;  // awesomeahhlight
uniform sampler2D hypTex;   // chr_hypno_sl_light

uniform vec2 uOrigin;       // light-space position of the sprite's top-left
uniform vec2 uSize;         // sprite size in world pixels
uniform vec4 uFrame;        // atlas uv rect (u, v, w, h); (0,0,1,1) for plain images

uniform vec4 uBg;           // light rects: centre x, centre y, half width, half height
uniform vec4 uPole;
uniform vec4 uCone1;
uniform vec4 uCone2;
uniform vec4 uHyp;

uniform vec4 uFlags;        // x: BgLight+Pole+PoleLight  y: PoleLight2  z: Hypno MainLight  w: Hypno SubLight
uniform float uBgEnergy;
uniform vec3 uLampEnergy;   // Pole, PoleLight, PoleLight2
uniform vec3 uMainColor;    // Hypno MainLight colour * energy
uniform float uSubEnergy;

vec4 lightAt(sampler2D t, vec4 r, vec2 p)
{
    vec2 uv = (p - r.xy) / (2.0 * r.zw) + 0.5;
    if (uv.x < 0.0 || uv.x > 1.0 || uv.y < 0.0 || uv.y > 1.0) return vec4(0.0);
    return texture2D(t, uv);   // premultiplied
}

void main()
{
    vec4 base = flixel_texture2D(bitmap, openfl_TextureCoordv);
    vec2 local = (openfl_TextureCoordv - uFrame.xy) / uFrame.zw;
    vec2 p = uOrigin + local * uSize;

    vec3 f = vec3(1.0);

    if (uFlags.x > 0.5)
    {
        vec4 b = lightAt(bgTex, uBg, p);
        vec3 brgb = b.a > 0.0 ? b.rgb / b.a : vec3(0.0);
        f = f * (1.0 - b.a) + b.a * brgb * uBgEnergy;

        f += lightAt(poleTex, uPole, p).rgb * uLampEnergy.x;
        f += lightAt(coneTex, uCone1, p).rgb * vec3(0.9418, 0.9795, 0.9697) * uLampEnergy.y;
    }
    if (uFlags.y > 0.5)
        f += lightAt(coneTex, uCone2, p).rgb * vec3(0.8039, 0.9608, 0.9137) * uLampEnergy.z;

    vec3 hyp = lightAt(hypTex, uHyp, p).rgb;
    if (uFlags.z > 0.5) f += hyp * uMainColor;
    if (uFlags.w > 0.5) f += hyp * uSubEnergy;

    gl_FragColor = vec4(clamp(base.rgb * f, 0.0, base.a), base.a);
}
