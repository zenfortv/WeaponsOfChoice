// /fx_mosh drag stage (the supermosh / P-frame-repeat streak look): horizontal bands of rows keep
// sliding sideways and smear their colours into long streaks; the rest shows the mosh underneath.
// Input 0: mosh output (this frame). Input 1: this stage's last frame (feedback_drag).
uniform float uDrag;     // 0..1 how many bands are dragging
uniform float uHold;     // 0..0.99 how long a streak survives (Bloom)
uniform float uSpeed;    // pixels per frame at full speed
uniform float uSeed;     // frame number
out vec4 fragColor;

float hash(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }

void main() {
    vec2 res = uTDOutputInfo.res.zw;
    vec2 uv = vUV.st;
    vec4 cur = texture(sTD2DInputs[0], uv);
    // bands of uneven height, re-dealt every ~12 frames
    float epoch = floor(uSeed / 12.0);
    float bandH = mix(4.0, 48.0, hash(vec2(floor(uv.y * res.y / 24.0), epoch)));
    float band = floor(uv.y * res.y / bandH);
    float h = hash(vec2(band, epoch + 3.1));
    float on = step(h, uDrag);
    float dir = hash(vec2(band, epoch + 7.7)) < 0.5 ? -1.0 : 1.0;
    float speed = mix(0.3, 1.0, hash(vec2(band, epoch + 1.3))) * uSpeed * dir;
    vec4 prev = texture(sTD2DInputs[1], uv - vec2(speed / res.x, 0.0));
    // a dragging band keeps its old streak (bright wins, like the glitch), fed a little by the new frame
    vec3 streak = max(prev.rgb * uHold, cur.rgb * (1.0 - uHold));
    vec3 c = mix(cur.rgb, streak, on);
    fragColor = TDOutputSwizzle(vec4(c, 1.0));
}
