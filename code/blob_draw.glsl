// /fx_blob: draws a green box around every tracked blob.
// Input 0: the video (only for the size). Boxes come in as the uniform array uBlobs (no texture upload: that stalled the GPU 34 ms).
uniform vec4 uBlobs[24];   // from script_boxes CHOP: u, v (lower left), w, h per blob; w = 0 empty
uniform vec3 uCol;     // colour scheme (Color menu)
out vec4 fragColor;

void main() {
    vec2 res = uTDOutputInfo.res.zw;
    vec2 px = vUV.st * res;
    float box = 0.0;
    for (int i = 0; i < 24; i++) {
        vec4 b = uBlobs[i];
        if (b.z <= 0.0) continue;
        vec2 lo = b.xy * res;
        vec2 hi = (b.xy + b.zw) * res;
        vec2 d = min(px - lo, hi - px);           // inside: both positive
        float inside = step(0.0, min(d.x, d.y));
        float edge = inside * (1.0 - step(2.0, min(d.x, d.y)));
        box = max(box, edge);
    }
    fragColor = TDOutputSwizzle(vec4(uCol * box, box));   // green outline
}
