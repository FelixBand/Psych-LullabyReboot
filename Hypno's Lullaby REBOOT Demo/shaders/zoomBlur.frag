#pragma header

uniform float blurWidth;
uniform float sampleCount;

void main()
{
    vec2 uv = openfl_TextureCoordv;

    // Fixed center of the screen
    vec2 center = vec2(0.5, 0.5);

    // Clamp the sample count to a safe integer range
    float count = clamp(floor(sampleCount + 0.5), 1.0, 32.0);

    vec4 color = vec4(0.0);
    float totalWeight = 0.0;

    // Use a constant loop limit for shader compatibility
    for (int i = 0; i < 32; i++)
    {
        if (float(i) < count)
        {
            float t = (count <= 1.0)
                ? 0.5
                : float(i) / (count - 1.0);

            float offset = (t - 0.5) * blurWidth;
            float scale = 1.0 + offset;

            vec2 sampleUV = center + (uv - center) * scale;
            sampleUV = clamp(sampleUV, vec2(0.001), vec2(0.999));

            float weight = 1.0 - abs(t - 0.5) * 0.4;

            color += flixel_texture2D(bitmap, sampleUV) * weight;
            totalWeight += weight;
        }
    }

    gl_FragColor = color / max(totalWeight, 0.001);
}