// /fx_blob "double" inside each blob box (user reference, 2026-11-20): the mirror/metal feedback picture,
// tinted green. Upper part = soft glow (blurred), lower part = sharp and dotted (particle look).
// Input 0: metal picture (sharp). Input 1: same, blurred (the glow).
// Boxes: uniform array uBlobs (u, v lower left, w, h; w = 0 empty), from script_boxes.
// Output rgb = the double inside the boxes, alpha = inside mask.
uniform vec4 uBlobs[24];
uniform float uSplit;     // 0..1 height of the dotted part, from the box's bottom
out vec4 fragColor;

uniform vec3 uCol;     // colour scheme (Color menu)
#define GREEN uCol

void main() {
    vec2 uv = vUV.st;
    vec2 px = gl_FragCoord.xy;
    float inside = 0.0;
    float local = 0.0;                       // height inside the box, 0 bottom .. 1 top
    for (int i = 0; i < 24; i++) {
        vec4 b = uBlobs[i];
        if (b.z <= 0.0) continue;
        vec2 d = min(uv - b.xy, b.xy + b.zw - uv);
        if (min(d.x, d.y) >= 0.0) {
            inside = 1.0;
            local = (uv.y - b.y) / b.w;
        }
    }
    // clamp: metal's picture can be negative (float formats) and pow() of a negative is NaN, which blacks out everything
    float sharp = clamp(dot(texture(sTD2DInputs[0], uv).rgb, vec3(0.299, 0.587, 0.114)), 0.0, 1.0);
    float soft = clamp(dot(texture(sTD2DInputs[1], uv).rgb, vec3(0.299, 0.587, 0.114)), 0.0, 1.0);
    // dotted: only every other pixel on a 3 px grid, brightened, so it reads as particles
    float dots = step(0.5, fract(px.x / 3.0)) * step(0.5, fract(px.y / 3.0));
    vec3 lower = GREEN * smoothstep(0.15, 0.7, sharp) * dots * 2.2;
    vec3 upper = GREEN * pow(soft, 0.8) * 1.6;
    float edge = smoothstep(uSplit - 0.02, uSplit + 0.02, local);
    vec3 c = mix(lower, upper, edge);
    fragColor = TDOutputSwizzle(vec4(c * inside, inside));
}
