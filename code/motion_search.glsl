// Block matching, the job an encoder does. One output pixel = one 16x16 macroblock.
// Input 0 current luma, input 1 previous luma, both at 1/4 resolution, so a block is 4x4 texels.
// Output xy: where this block's pixels were in the previous frame, in UV. z: match error.

uniform float uRange;   // search radius in luma texels (8 = 32 output pixels)

out vec4 fragColor;

const int BLOCK = 4;

float sad(ivec2 o, ivec2 d, ivec2 size)
{
    float sum = 0.0;
    for (int y = 0; y < BLOCK; y++)
    for (int x = 0; x < BLOCK; x++)
    {
        ivec2 p = o + ivec2(x, y);
        float a = texelFetch(sTD2DInputs[0], min(p, size - 1), 0).r;
        float b = texelFetch(sTD2DInputs[1], clamp(p + d, ivec2(0), size - 1), 0).r;
        sum += abs(a - b);
    }
    return sum;
}

void main()
{
    ivec2 size = textureSize(sTD2DInputs[0], 0);
    ivec2 o = ivec2(gl_FragCoord.xy) * BLOCK;
    int range = int(uRange);

    // Still blocks stop here, which is most of the frame in most footage.
    float best = sad(o, ivec2(0), size);
    ivec2 bestD = ivec2(0);

    if (best > 0.12)
    {
        best += 0.04;   // like an encoder, a vector has to earn its cost
        for (int y = -range; y <= range; y += 2)
        for (int x = -range; x <= range; x += 2)
        {
            ivec2 d = ivec2(x, y);
            float c = sad(o, d, size) + 0.002 * float(abs(x) + abs(y));
            if (c < best) { best = c; bestD = d; }
        }
        ivec2 coarse = bestD;
        for (int y = -1; y <= 1; y++)
        for (int x = -1; x <= 1; x++)
        {
            ivec2 d = coarse + ivec2(x, y);
            float c = sad(o, d, size) + 0.002 * float(abs(d.x) + abs(d.y));
            if (c < best) { best = c; bestD = d; }
        }
    }

    fragColor = TDOutputSwizzle(vec4(vec2(bestD) / vec2(size), best / 16.0, 1.0));
}
