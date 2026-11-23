// Gamepad blueprint on the control panel (MetalShow.88). Own drawing (signed distance shapes), not an image.
// Input 0 = the panel, passed through outside the pad box. Input 1 = pad data, 1 row (choptoTOP of select_pad):
//  0 A  1 B  2 X  3 Y  4 LB  5 RB  6 Back  7 Start  8 L3  9 R3  10 LT  11 RT  12 dpadX  13 dpadY
//  14 LX  15 LY  16 RX  17 RY  18 connected
// Outlines only: dim grey-teal with no pad, light green when the pad is connected; a pressed control fills green.
uniform vec4 uBox;          // centre x, centre y (panel pixels, y up), scale (pixels per unit), unused
out vec4 fragColor;

float pad(int i) { return texelFetch(sTD2DInputs[1], ivec2(i, 0), 0).r; }

float sdBox(vec2 p, vec2 b, float r) { vec2 q = abs(p) - b + r; return length(max(q, 0.0)) + min(max(q.x, q.y), 0.0) - r; }
float sdCircle(vec2 p, float r) { return length(p) - r; }
float sdCapsule(vec2 p, vec2 a, vec2 b, float r) {
    vec2 pa = p - a, ba = b - a;
    float h = clamp(dot(pa, ba) / dot(ba, ba), 0.0, 1.0);
    return length(pa - ba * h) - r;
}
float smin(float a, float b, float k) { float h = clamp(0.5 + 0.5 * (b - a) / k, 0.0, 1.0); return mix(b, a, h) - k * h * (1.0 - h); }

vec3 LINE_OFF = vec3(0.22, 0.32, 0.33);
vec3 LINE_ON  = vec3(0.62, 1.00, 0.62);
vec3 FILL_ON  = vec3(0.30, 0.95, 0.40);

// one outlined control: d = distance, lit = 0-1 pressed amount
vec3 control(vec3 col, float d, float lit, vec3 line, float px) {
    float edge = 1.0 - smoothstep(0.0, px * 1.3, abs(d));
    col = mix(col, FILL_ON * 0.85, lit * (1.0 - smoothstep(-px, px, d)));
    return mix(col, mix(line, vec3(0.85, 1.0, 0.85), lit), edge);
}

void main()
{
    vec2 res = uTDOutputInfo.res.zw;
    vec2 pix = vUV.st * res;
    vec4 base = texture(sTD2DInputs[0], vUV.st);
    vec2 p = (pix - uBox.xy) / uBox.z;            // pad units, origin at the centre, y up
    if (abs(p.x) > 112.0 || abs(p.y) > 92.0) { fragColor = base; return; }
    float px = 1.0 / uBox.z;                      // one panel pixel in pad units
    float on = step(0.5, pad(18));
    vec3 line = mix(LINE_OFF, LINE_ON, on);
    vec3 col = base.rgb;

    // body: top bar + two grips
    float body = sdBox(p - vec2(0.0, 18.0), vec2(78.0, 32.0), 22.0);
    body = smin(body, sdCapsule(p, vec2(-52.0, 10.0), vec2(-74.0, -52.0), 28.0), 14.0);
    body = smin(body, sdCapsule(p, vec2(52.0, 10.0), vec2(74.0, -52.0), 28.0), 14.0);
    body = max(body, -sdCircle(p - vec2(0.0, -76.0), 42.0));      // the gap between the grips
    float inside = 1.0 - smoothstep(-px, px, body);

    // blueprint grid + centre lines inside the body (fainter with no pad)
    vec2 g = abs(fract(p / 10.0) - 0.5) * 10.0;
    float grid = (1.0 - smoothstep(0.0, px * 1.2, min(g.x, g.y))) * inside;
    col = mix(col, line, grid * (0.10 + 0.10 * on));
    float axis = (1.0 - smoothstep(0.0, px, abs(p.x))) * step(0.5, fract(p.y / 6.0)) * inside;
    col = mix(col, line, axis * 0.35);
    col = control(col, body, 0.0, line, px);
    col = control(col, body + 5.0, 0.0, line * 0.55, px);         // inner contour, like a drawing

    // triggers (fill rises with the pull) and bumpers
    for (int s = 0; s < 2; s++) {
        float sx = s == 0 ? -1.0 : 1.0;
        float t = clamp(pad(10 + s), 0.0, 1.0);
        vec2 tp = p - vec2(sx * 54.0, 70.0);
        float dt = sdBox(tp, vec2(16.0, 9.0), 4.0);
        float fillT = step(tp.y, -9.0 + 18.0 * t) * t;
        col = control(col, dt, fillT, line, px);
        col = control(col, sdBox(p - vec2(sx * 54.0, 55.0), vec2(24.0, 4.0), 3.0), step(0.5, pad(4 + s)), line, px);
    }

    // sticks: ring + cap that moves with the axis, cap fills on L3 / R3
    vec2 ls = vec2(-50.0, 20.0), rs = vec2(24.0, -4.0);
    vec2 lm = vec2(pad(14), pad(15)) * 7.0, rm = vec2(pad(16), pad(17)) * 7.0;
    col = control(col, sdCircle(p - ls, 17.0), 0.0, line * 0.7, px);
    col = control(col, sdCircle(p - ls - lm, 10.5), max(step(0.5, pad(8)), 0.35 * clamp(length(lm) / 7.0, 0.0, 1.0)), line, px);
    col = control(col, sdCircle(p - rs, 17.0), 0.0, line * 0.7, px);
    col = control(col, sdCircle(p - rs - rm, 10.5), max(step(0.5, pad(9)), 0.35 * clamp(length(rm) / 7.0, 0.0, 1.0)), line, px);

    // d-pad: four arms, each lights on its own direction
    vec2 dp = p - vec2(-24.0, -4.0);
    float dx = pad(12), dy = pad(13);
    col = control(col, sdBox(dp - vec2(-8.0, 0.0), vec2(6.0, 4.5), 1.5), step(0.5, -dx), line, px);
    col = control(col, sdBox(dp - vec2(8.0, 0.0), vec2(6.0, 4.5), 1.5), step(0.5, dx), line, px);
    col = control(col, sdBox(dp - vec2(0.0, 8.0), vec2(4.5, 6.0), 1.5), step(0.5, dy), line, px);
    col = control(col, sdBox(dp - vec2(0.0, -8.0), vec2(4.5, 6.0), 1.5), step(0.5, -dy), line, px);

    // face buttons A B X Y (diamond, A at the bottom)
    vec2 fb = vec2(50.0, 20.0);
    col = control(col, sdCircle(p - fb - vec2(0.0, -11.0), 6.5), step(0.5, pad(0)), line, px);   // A
    col = control(col, sdCircle(p - fb - vec2(11.0, 0.0), 6.5), step(0.5, pad(1)), line, px);    // B
    col = control(col, sdCircle(p - fb - vec2(-11.0, 0.0), 6.5), step(0.5, pad(2)), line, px);   // X
    col = control(col, sdCircle(p - fb - vec2(0.0, 11.0), 6.5), step(0.5, pad(3)), line, px);    // Y

    // back / start
    col = control(col, sdBox(p - vec2(-12.0, 22.0), vec2(5.0, 3.0), 1.5), step(0.5, pad(6)), line, px);
    col = control(col, sdBox(p - vec2(12.0, 22.0), vec2(5.0, 3.0), 1.5), step(0.5, pad(7)), line, px);
    // centre ring (power button spot, no logo)
    col = control(col, sdCircle(p - vec2(0.0, 38.0), 6.0), 0.0, line * 0.8, px);

    fragColor = TDOutputSwizzle(vec4(col, base.a));
}
