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
uniform float uWarpScale;      // multiplies the retention warp distance (1.0 = exactly the Godot shader)
uniform float uSquiggleScale;  // multiplies the squiggle warp distance (1.0 = exactly the Godot shader)
uniform float uView;           // debug: 0 = normal, 1 = left half untouched / right half effect, 2 = show the offset field

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

// The noise texture is only 418x311 and gets stretched over the whole screen, so it is filtered by hand here:
// with the engine's default (nearest) sampling the warp comes out blocky / pixelated.
const vec2 NOISE_SIZE = vec2(418.0, 311.0);

vec2 noiseTexel(vec2 i)
{
    i = clamp(i, vec2(0.0), NOISE_SIZE - 1.0);
    return texture2D(noiseTex, (i + 0.5) / NOISE_SIZE).xy;
}

vec2 noiseOffset(vec2 uv, float wave)
{
    if (wave <= 0.0) return vec2(0.0);

    vec2 nuv = uv * vec2(3.0, 1.0);
    nuv.x -= uTime * 0.15;

    float index = floor(nuv.x);
    vec2 local = vec2(fract(nuv.x), fract(nuv.y));
    if (mod(index, 2.0) != 0.0) local.x = 1.0 - local.x;

    vec2 p = local * NOISE_SIZE - 0.5;
    vec2 i = floor(p);
    vec2 f = p - i;
    vec2 n = mix(mix(noiseTexel(i), noiseTexel(i + vec2(1.0, 0.0)), f.x),
                 mix(noiseTexel(i + vec2(0.0, 1.0)), noiseTexel(i + vec2(1.0, 1.0)), f.x), f.y);

    return n * wave * 0.0125;
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

    // distortion vectors are worked out ONCE per pixel (the noise is smooth, so this is the same picture as
    // re-evaluating it for every blur tap, at a fraction of the cost)
    vec2 os = noiseOffset(uv, uSquiggle * uSquiggleScale);   // SquiggleLayer (timeline)
    vec2 ot = noiseOffset(uv, uWave * uWarpScale);           // retention water

    // debug: show the displacement field (red = x, green = y, grey = none)
    if (uView > 1.5)
    {
        gl_FragColor = vec4(0.5 + (os + ot) * 40.0, 0.5, 1.0);
        return;
    }
    // debug: left half is the untouched screen
    if (uView > 0.5 && uv.x < 0.5)
    {
        gl_FragColor = texture2D(bitmap, uv);
        return;
    }

    bool hasS = uSquiggle > 0.0;
    bool hasT = uWave > 0.0;
    vec2 s1 = os;
    vec2 s2 = os * (1.0 - uSquiggleGhost);
    vec2 t1 = ot;
    vec2 t2 = ot * (1.0 - uGhost);

    // full water: each layer averages its image with a "ghost" copy
    vec4 col;
    if (hasS && hasT)
        col = (texture2D(bitmap, uv + s1 + t1) + texture2D(bitmap, uv + s1 + t2) +
               texture2D(bitmap, uv + s2 + t1) + texture2D(bitmap, uv + s2 + t2)) * 0.25;
    else if (hasS)
        col = (texture2D(bitmap, uv + s1) + texture2D(bitmap, uv + s2)) * 0.5;
    else if (hasT)
        col = (texture2D(bitmap, uv + t1) + texture2D(bitmap, uv + t2)) * 0.5;
    else
        col = texture2D(bitmap, uv);

    if (uBlur > 0.0)
    {
        // radial blur of the warped picture: single tap per step, 8 steps
        vec2 d = uv - vec2(0.5);
        vec2 w = s1 + t1;
        float pre = uBlur * 0.1 * (1.0 / 8.0);
        for (int i = 1; i < 9; i++)
        {
            float sc = 1.0 + float(i) * pre;
            col += texture2D(bitmap, d * sc + vec2(0.5) + w);
        }
        col /= 9.0;
    }

    if (uSaturation != 1.0 || uContrast != 1.0) col = grade(col);   // once, after averaging

    gl_FragColor = col;
}
