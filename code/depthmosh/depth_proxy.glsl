// Depth without a depth camera or an AI model (the free, node-only option).
// Near things move more than far things (parallax), and in stage footage bright things are usually
// the subject. Both are blended into one depth value, then smoothed over time so it doesn't boil.
// Input 0: source video (/input/out1)
// Input 1: motion field (/fx_mosh glsl_field output, xy = UV offset per frame)
// Input 2: this shader's previous output (feedback TOP), for the time smoothing
// Output: rgb = the source video unchanged, a = depth (0 far, 1 near). Feeds glsl_mosh input 1.

uniform float uMotion;   // 0 = brightness only, 1 = motion only (good start 0.6)
uniform float uGain;     // how much motion counts as "near" (good start 40)
uniform float uSmooth;   // 0 = new value every frame, 0.95 = very calm (good start 0.85)
uniform float uBlur;     // radius in pixels of the soft fill (good start 6)
uniform float uInvert;   // 1 = dark is near (for white-background footage)

out vec4 fragColor;

float luma(vec3 c) { return dot(c, vec3(0.299, 0.587, 0.114)); }

void main()
{
    vec2 uv = vUV.st;
    vec2 px = uTDOutputInfo.res.xy;

    // 9 taps on a ring: a soft blob of brightness, not the fine texture
    float b = 0.0;
    float m = 0.0;
    for (int i = 0; i < 9; i++)
    {
        float a = float(i) * 0.6981;   // 2 pi / 9
        vec2 o = (i == 0) ? vec2(0.0) : vec2(cos(a), sin(a)) * px * uBlur;
        b += luma(texture(sTD2DInputs[0], uv + o).rgb);
        m += length(texture(sTD2DInputs[1], uv + o * 2.0).zw);   // measured vectors, not the played ones
    }
    b /= 9.0;
    m = clamp(m / 9.0 * uGain, 0.0, 1.0);

    b = mix(b, 1.0 - b, uInvert);
    float d = mix(b, m, uMotion);
    d = smoothstep(0.02, 0.98, d);

    float last = texture(sTD2DInputs[2], uv).a;
    d = mix(d, last, uSmooth);

    fragColor = TDOutputSwizzle(vec4(texture(sTD2DInputs[0], uv).rgb, d));
}
