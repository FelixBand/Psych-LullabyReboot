#pragma header

// Emulates the three Godot PointLight2D nodes of the Safety Lullaby intro cutscene (intro.tscn).
// All three use blend_mode = Mix, evaluated in scene-tree order:
//     f = f * (1 - a) + a * lightRGB * colour * energy
//   BGLight     radial dark vignette (darkness_gradient)             -> the "darkness" of the whole cutscene
//   PoleLight   white cone (awesomeahhlight), flickers in the opening and moves per scene
//   PoleLightBG the two street-light glows (pendulum_drop_lights), colour (1, 1, 0.733) at energy 4.07
// Final colour = clamp(base * f, 0, base.a), same as lightMask.frag.
// All rects are in "image space": the 1280x720 art, where Godot units = image pixels * 1.5.

uniform sampler2D bgTex;    // cutscenes/intro/darkness_gradient
uniform sampler2D coneTex;  // alley/awesomeahhlight
uniform sampler2D glowTex;  // cutscenes/intro/pendulum_drop_lights

uniform vec2 uOrigin;       // image-space position of the displayed frame's top-left
uniform vec2 uSize;         // image-space size of the displayed frame
uniform vec4 uFrame;        // atlas uv rect (u, v, w, h); (0,0,1,1) for plain images
uniform float uRot;         // 1 = frame stored rotated in the atlas

uniform vec4 uBg;           // rects: centre x, centre y, half width, half height
uniform vec4 uPole;
uniform vec4 uGlow;
uniform vec2 uPoleRot;      // cos, sin of the PoleLight node rotation
uniform vec3 uGlowColor;    // PoleLightBG colour * energy
uniform vec3 uOn;           // x: BGLight  y: PoleLight  z: PoleLightBG

vec4 lightAt(sampler2D t, vec4 r, vec2 d)
{
    vec2 uv = d / (2.0 * r.zw) + 0.5;
    if (uv.x < 0.0 || uv.x > 1.0 || uv.y < 0.0 || uv.y > 1.0) return vec4(0.0);
    return texture2D(t, uv);   // premultiplied
}

vec3 mixLight(vec3 f, vec4 t, vec3 colour)
{
    vec3 rgb = t.a > 0.0 ? t.rgb / t.a : vec3(0.0);
    return f * (1.0 - t.a) + t.a * rgb * colour;
}

void main()
{
    vec4 base = flixel_texture2D(bitmap, openfl_TextureCoordv);
    vec2 local = (openfl_TextureCoordv - uFrame.xy) / uFrame.zw;
    if (uRot > 0.5) local = vec2(local.y, 1.0 - local.x);
    vec2 p = uOrigin + local * uSize;

    vec3 f = vec3(1.0);

    if (uOn.x > 0.5)
        f = mixLight(f, lightAt(bgTex, uBg, p - uBg.xy), vec3(1.0));

    if (uOn.y > 0.5)
    {
        vec2 d = p - uPole.xy;
        // inverse of the node rotation (Godot rotates clockwise on screen)
        vec2 l = vec2(d.x * uPoleRot.x + d.y * uPoleRot.y, -d.x * uPoleRot.y + d.y * uPoleRot.x);
        f = mixLight(f, lightAt(coneTex, uPole, l), vec3(1.0));
    }

    if (uOn.z > 0.5)
        f = mixLight(f, lightAt(glowTex, uGlow, p - uGlow.xy), uGlowColor);

    gl_FragColor = vec4(clamp(base.rgb * f, 0.0, base.a), base.a);
}
