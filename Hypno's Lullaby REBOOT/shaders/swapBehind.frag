#pragma header

// Recolours marked notes/strums pixel by pixel, based on the colour behind them.
// Marked sprites are drawn with ADD blending and a flat marker colour, so they only add `gain` to BLUE.
// Red and green are therefore still the real backdrop. Every backdrop colour in this effect has blue == green
// (060606, 511414, 6C1B1B, A6A3A3, and any blend between them), so:
//   * a note is wherever blue is higher than green:  cover = (blue - green) / gain
//   * the backdrop under it is simply (red, green, green)
// Which backdrop it is = the NEAREST palette colour (s0..s3, compared on red+green only). No exact shades or
// colour paths are needed, so anti-aliased edges, the diagonal wipe and in-between shades all pick the closest one.
// (Pixels far from every palette colour AND every line between two of them are other sprites and are ignored.)
//
//   a0..a3  = what a marked pixel becomes over each backdrop in mode A (before the tween)
//   b0..b3  = same in mode B (after the tween)
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
uniform float thr;      // smallest (blue - green) counted as a note (0.01)
uniform float uOn;      // 1 = effect on, 0 = pass-through

const float TOL = 0.06; // backdrop must lie within this (red/green distance) of some palette colour OR of a line between two of
                        // them (anti-aliased edges, wipes), otherwise it's some other blue-ish sprite and is left alone

float segDist(vec2 p, vec2 a, vec2 b)
{
    vec2 ab = b - a;
    float t = clamp(dot(p - a, ab) / dot(ab, ab), 0.0, 1.0);
    return distance(p, a + ab * t);
}

void main()
{
    vec4 c = flixel_texture2D(bitmap, openfl_TextureCoordv);
    float extra = c.b - c.g;

    if (uOn < 0.5 || c.a < 0.99 || extra < thr)
    {
        gl_FragColor = c;
        return;
    }

    vec2 rg = c.rg;
    float d0 = distance(rg, s0.rg);
    float d1 = distance(rg, s1.rg);
    float d2 = distance(rg, s2.rg);
    float d3 = distance(rg, s3.rg);

    float best = d0;
    vec3 result = mix(a0, b0, uMix);
    if (d1 < best) { best = d1; result = mix(a1, b1, uMix); }
    if (d2 < best) { best = d2; result = mix(a2, b2, uMix); }
    if (d3 < best) { best = d3; result = mix(a3, b3, uMix); }

    float edge = min(min(segDist(rg, s0.rg, s1.rg), segDist(rg, s1.rg, s2.rg)),
                     min(segDist(rg, s2.rg, s3.rg), segDist(rg, s0.rg, s3.rg)));
    edge = min(edge, min(segDist(rg, s0.rg, s2.rg), segDist(rg, s1.rg, s3.rg)));

    if (min(best, edge) > TOL)
    {
        gl_FragColor = c;     // not one of our backdrops (some other blue-ish sprite): leave it
        return;
    }

    float cover = clamp(extra / gain, 0.0, 1.0);
    vec3 backdrop = vec3(c.r, c.g, c.g);
    gl_FragColor = vec4(mix(backdrop, result, cover), 1.0);
}
