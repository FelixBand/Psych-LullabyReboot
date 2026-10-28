#pragma header

// Draws a sprite as a flat marker colour (uMark) wherever the sprite is opaque, ignoring the texture's own
// colours. Used with ADD blending so the swapBehind filter can read the sprite's exact coverage.
uniform vec3 uMark;

void main()
{
    vec4 c = flixel_texture2D(bitmap, openfl_TextureCoordv);
    gl_FragColor = vec4(uMark * c.a, c.a);
}
