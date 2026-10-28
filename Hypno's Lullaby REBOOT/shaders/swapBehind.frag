#pragma header

// Recolours marked notes/strums pixel by pixel, based on the colour behind them.
// Marked sprites are drawn with ADD blending and flat marker colour, so they only add `gain` to BLUE.
// Red and green still show the real backdrop; red alone is enough to look the backdrop up in the palette
// s0..s3 (sorted by red, ascending). A note is where blue is higher than the backdrop allows, and its
// exact coverage is (excess blue / gain).
//
// What a marked pixel becomes depends on the backdrop colour:
//   a0..a3  = result in mode A (before the tween)
//   b0..b3  = result in mode B (after the tween)
//   uMix    = 0 -> mode A, 1 -> mode B (tween this for the little colour change)
uniform vec3 s0;
uniform vec3 s1;
uniform vec3 s2;
uniform vec3 s3;
uniform vec3 a0;
uniform vec3 a1;
uniform vec3 a2;
uniform vec3 a3;
uniform vec3 b0;
uniform vec3 b1;
uniform vec3 b2;
uniform vec3 b3;
uniform float uMix;
uniform float gain;     // blue added by a marked sprite (77/255 = 0.302)
uniform float thr;      // smallest blue excess counted as a note (0.01)
uniform float uOn;      // 1 = effect on, 0 = pass-through

void main()
{
    vec4 c = flixel_texture2D(bitmap, openfl_TextureCoordv);
    float r = c.r;

    if (uOn < 0.5 || c.a < 0.99 || r < s0.r - 0.03 || r > s3.r + 0.03)
    {
        gl_FragColor = c;
        return;
    }

    vec3 o0 = mix(a0, b0, uMix);
    vec3 o1 = mix(a1, b1, uMix);
    vec3 o2 = mix(a2, b2, uMix);
    vec3 o3 = mix(a3, b3, uMix);

    vec3 bg;
    vec3 result;
    if (r <= s1.r)
    {
        float t = clamp((r - s0.r) / (s1.r - s0.r), 0.0, 1.0);
        bg = mix(s0, s1, t);
        result = mix(o0, o1, t);
    }
    else if (r <= s2.r)
    {
        float t = clamp((r - s1.r) / (s2.r - s1.r), 0.0, 1.0);
        bg = mix(s1, s2, t);
        result = mix(o1, o2, t);
    }
    else
    {
        float t = clamp((r - s2.r) / (s3.r - s2.r), 0.0, 1.0);
        bg = mix(s2, s3, t);
        result = mix(o2, o3, t);
    }

    float extra = c.b - bg.b;
    if (extra < thr || abs(c.g - bg.g) > 0.03)
    {
        gl_FragColor = c;
        return;
    }

    float cover = clamp(extra / gain, 0.0, 1.0);
    gl_FragColor = vec4(mix(bg, result, cover), 1.0);
}
