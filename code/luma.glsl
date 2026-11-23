// /fx_luma (MetalShow.54): brightness layers. The brightness of the clean picture (clip / HUD / POP, input 1)
// picks which layer shows: dark band, middle band, bright band.
//   inputs: 0 = the chain so far (blob / edge / crash on top of metal), 1 = clean input, 2 = metal only
//   Order 0: dark CLIP   | mid METAL | bright FX (blob...)
//   Order 1: dark FX     | mid METAL | bright CLIP
//   Order 2: dark METAL  | mid CLIP  | bright FX
// uL = (split = centre of the middle band, width of the middle band, soft edge, order)
// uM = (flip envelope: Action1 swaps dark and bright while it is up, sweep envelope: Action2 runs the split 0 -> 1,
//       kick push on the split)
uniform vec4 uL;
uniform vec3 uM;
out vec4 fragColor;

void main()
{
    vec2 uv = vUV.st;
    vec4 fx = texture(sTD2DInputs[0], uv);
    vec4 clip = texture(sTD2DInputs[1], uv);
    vec4 metal = texture(sTD2DInputs[2], uv);
    float l = dot(max(clip.rgb, 0.0), vec3(0.299, 0.587, 0.114));

    float split = uL.x + uM.z;
    if (uM.y > 0.001) split = 1.0 - uM.y;          // SWEEP: the middle band runs from dark to bright
    float lo = split - uL.y * 0.5, hi = split + uL.y * 0.5;
    float s = max(uL.z, 0.002);
    float wDark = 1.0 - smoothstep(lo - s, lo + s, l);
    float wBright = smoothstep(hi - s, hi + s, l);
    float wMid = clamp(1.0 - wDark - wBright, 0.0, 1.0);

    vec4 dark, mid, bright;
    int order = int(uL.w + 0.5);
    if (order == 1)      { dark = fx;    mid = metal; bright = clip; }
    else if (order == 2) { dark = metal; mid = clip;  bright = fx; }
    else                 { dark = clip;  mid = metal; bright = fx; }
    if (uM.x > 0.3) { vec4 t = dark; dark = bright; bright = t; }   // FLIP

    vec4 c = dark * wDark + mid * wMid + bright * wBright;
    fragColor = TDOutputSwizzle(vec4(c.rgb, 1.0));
}
