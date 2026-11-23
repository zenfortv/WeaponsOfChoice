// pop_mold (MetalShow.59): moves the point models (/src_pop deco / spiral / skeleton and the HUD weapons) with the
// music and the pad, and leaves them as they are when nothing happens. Position only.
// Uniforms (glslPOP auto-declares them as float, set on the Vectors page):
//   uBass     kick x 'pop bass'          -> the model breathes out from its centre + a ripple runs through it
//   uExplode  envelope 0..1 (pad / BOOM)  -> points fly out in random directions and come back
//   uTwist    knob + mid band + envelope  -> twist around the vertical axis, more at the top and bottom
//   uSlice    strobe flash x 'pop slice'  -> horizontal slices jump sideways on each flash
//   uSeed     flash counter               -> a new slice pattern every flash
//   uMelt     envelope 0..1 (pad)         -> points drip down and come back
//   uQuake    envelope 0..1 (pad / BOOM)  -> an earthquake front crosses the model (uFront -1.3 .. 1.3), shaking it
//   uTime     seconds, for the shake noise
//   (the scan rectangle that rides on the quake front is geometry, geo_scan, not in here - MetalShow.62)
//   uSize     model half height, uCy model centre height
float H(float n) { return fract(sin(n) * 43758.5453); }
vec3 H3(float n) { return vec3(H(n), H(n + 17.13), H(n + 41.71)) * 2.0 - 1.0; }

void main()
{
    uint idx = gl_GlobalInvocationID.x;
    if (idx >= uint(P.length())) return;
    vec3 p = TDIn_P();
    float fi = float(idx);
    float h = max(uSize, 0.001);
    vec3 c = vec3(0.0, uCy, 0.0);
    vec3 d = p - c;
    float r = length(d);
    vec3 dir = r > 1e-5 ? d / r : vec3(0.0, 1.0, 0.0);

    // bass: breathe + ripple + a tremor
    float ripple = sin(r / h * 10.0 - uBass * 9.0);
    p += dir * uBass * h * (0.05 * (0.5 + H(fi)) + 0.04 * ripple);
    float tick = floor(uTime * 30.0);
    p += H3(fi * 0.37 + tick) * uBass * h * 0.035;

    // earthquake: a front crosses the model left to right, points near it shake hard and heave
    float x = d.x / h;
    float w = exp(-pow((x - uFront) * 2.2, 2.0)) + 0.25 * smoothstep(0.0, 1.0, uFront - x) * step(x, uFront);
    p += H3(fi * 0.71 + tick * 1.7) * uQuake * w * h * 0.22;
    p.y += sin(x * 9.0 - uTime * 14.0) * uQuake * w * h * 0.12;

    // twist
    float a = uTwist * (d.y / h) * 2.5;
    vec2 q = p.xz - c.xz;
    p.xz = vec2(q.x * cos(a) - q.y * sin(a), q.x * sin(a) + q.y * cos(a)) + c.xz;

    // explode
    p += (dir * 0.6 + H3(fi) * 0.8) * uExplode * h * 1.2;

    // slice glitch on strobe flashes
    float band = floor((p.y - c.y) / h * 7.0 + uSeed * 3.7);
    p.x += (H(band + uSeed * 7.3) - 0.5) * uSlice * h * 0.9;

    // melt
    p.y -= uMelt * h * 1.6 * H(fi * 1.31) * (0.3 + 0.7 * H(fi * 2.17));

    P[idx] = p;
}
