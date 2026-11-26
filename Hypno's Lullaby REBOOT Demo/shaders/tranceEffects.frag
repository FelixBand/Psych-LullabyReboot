#pragma header

// Safety Lullaby trance screen effects, all four Godot layers in one pass:
// water distortion -> HSV saturation -> contrast -> radial blur (trance_shaders.gd).

uniform sampler2D noiseTex;
uniform float uTime;
uniform float uWave;
uniform float uGhost;
uniform float uSaturation;
uniform float uContrast;
uniform float uBlur;
uniform float uSquiggle;       // song-timeline water warp (SquiggleLayer WAVE_STRENGTH, 0..2)
uniform float uSquiggleGhost;  // SquiggleLayer GHOST_STRENGTH (0.449 in the scene)

vec3 rgb2hsv(vec3 c)
{
    vec4 K = vec4(0.0, -1.0 / 3.0, 2.0 / 3.0, -1.0);
    vec4 p = mix(vec4(c.bg, K.wz), vec4(c.gb, K.xy), step(c.b, c.g));
    vec4 q = mix(vec4(p.xyw, c.r), vec4(c.r, p.yzx), step(p.x, c.r));
    float d = q.x - min(q.w, q.y);
    float e = 1.0e-10;
    return vec3(abs(q.z + (q.w - q.y) / (6.0 * d + e)), d / (q.x + e), q.x);
}

vec3 hsv2rgb(vec3 c)
{
    vec4 K = vec4(1.0, 2.0 / 3.0, 1.0 / 3.0, 3.0);
    vec3 p = abs(fract(c.xxx + K.xyz) * 6.0 - K.www);
    return c.z * mix(K.xxx, clamp(p - K.xxx, 0.0, 1.0), c.y);
}

vec2 noiseOffset(vec2 uv, float wave)
{
    vec2 nuv = uv * vec2(3.0, 1.0);
    nuv.x -= uTime * 0.15;

    float index = floor(nuv.x);
    vec2 local = vec2(fract(nuv.x), fract(nuv.y));
    if (mod(index, 2.0) != 0.0) local.x = 1.0 - local.x;

    return texture2D(noiseTex, local).xy * wave * 0.0125;
}

// retention based distortion (trance_shaders.gd WaterEffect)
vec4 tranceWater(vec2 uv)
{
    if (uWave <= 0.0) return texture2D(bitmap, uv);

    vec2 offset = noiseOffset(uv, uWave);
    vec4 c = texture2D(bitmap, uv + offset);
    c += texture2D(bitmap, uv + offset * (1.0 - uGhost));
    return c * 0.5;
}

// timeline distortion (SquiggleLayer), applied on top of the retention one
vec4 water(vec2 uv)
{
    if (uSquiggle <= 0.0) return tranceWater(uv);

    vec2 offset = noiseOffset(uv, uSquiggle);
    vec4 c = tranceWater(uv + offset);
    c += tranceWater(uv + offset * (1.0 - uSquiggleGhost));
    return c * 0.5;
}

vec4 grade(vec4 c)
{
    if (c.a <= 0.0) return c;
    vec3 s = c.rgb / c.a;
    vec3 hsv = rgb2hsv(s);
    hsv.y *= uSaturation;
    s = hsv2rgb(hsv);
    s = 0.5 + uContrast * (s - 0.5);
    return vec4(clamp(s, 0.0, 1.0) * c.a, c.a);
}

void main()
{
    vec2 uv = openfl_TextureCoordv;
    vec4 col = grade(water(uv));

    if (uBlur > 0.0)
    {
        vec2 d = uv - vec2(0.5);
        float pre = uBlur * 0.1 * (1.0 / 14.0);
        for (int i = 1; i < 15; i++)
        {
            float sc = 1.0 + float(i) * pre;
            col += grade(water(d * sc + vec2(0.5)));
        }
        col /= 15.0;
    }

    gl_FragColor = col;
}
