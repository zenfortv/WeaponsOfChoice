// STREAK stage: pixel-stretch / drip mosh in several directions (user's reference: cyan columns
// pouring down, rough purple blocks beside them). Lanes of pixels keep sliding and stretch the colour
// they picked up; each lane has its own speed, so the ends are jagged. Alpha = height of the streak,
// for mosh_volume.glsl, which lights it so the columns look like solid bars.
// Feedback: Input 0 this frame (mosh output or source, A = depth if it has one, else 1)
//           Input 1 this stage's last frame (feedback TOP, RGBA 16-bit float)
// Output RGBA, A = height (0 floor .. 1 top).

uniform float uAmount;   // 0..1 share of lanes that stretch [0.6]
uniform float uSpeed;    // px per frame at full speed [6]
uniform float uHold;     // 0..0.995 how long a streak lives [0.97]
uniform float uLane;     // lane width in px, 1 = per pixel, 4 = chunky columns [2]
uniform float uLo;       // brightness window that starts streaks (pixel-sort style) [0.35]
uniform float uHi;       //                                                     [1.0]
uniform float uDirs;     // 0 = all down, 1 = down+up, 2 = 4 directions in regions [2]
uniform float uRegion;   // size of the direction regions, bigger = fewer regions [2.5]
uniform float uDrift;    // how fast the regions move [0.05]
uniform float uTime;     // absTime.seconds
uniform float uSeed;     // re-deal lanes: changes on a beat / pulse

out vec4 fragColor;

float hash(vec2 p)
{
    vec3 q = fract(vec3(p.xyx) * 0.1031);
    q += dot(q, q.yzx + 33.33);
    return fract((q.x + q.y) * q.z);
}

float noise(vec2 p)
{
    vec2 i = floor(p), f = fract(p);
    f = f * f * (3.0 - 2.0 * f);
    return mix(mix(hash(i), hash(i + vec2(1, 0)), f.x), mix(hash(i + vec2(0, 1)), hash(i + vec2(1, 1)), f.x), f.y);
}

float luma(vec3 c) { return dot(c, vec3(0.299, 0.587, 0.114)); }

void main()
{
    vec2 res = uTDOutputInfo.res.zw;
    vec2 px = uTDOutputInfo.res.xy;
    vec2 uv = vUV.st;

    // direction of this region: down, up, left, right
    float r = noise(uv * uRegion + vec2(uTime * uDrift, uSeed * 0.37));
    int k = 0;                                   // down
    if (uDirs > 0.5) k = r < 0.5 ? 0 : 1;        // down / up
    if (uDirs > 1.5) k = r < 0.38 ? 0 : r < 0.76 ? 1 : r < 0.88 ? 2 : 3;  // mostly vertical, some sideways
    vec2 dir = k == 0 ? vec2(0, -1) : k == 1 ? vec2(0, 1) : k == 2 ? vec2(-1, 0) : vec2(1, 0);

    // lanes run along the direction, so they are counted across it
    float across = (k < 2) ? gl_FragCoord.x : gl_FragCoord.y;
    float lane = floor(across / max(uLane, 1.0));
    float on = step(hash(vec2(lane, uSeed + float(k) * 11.0)), uAmount);
    float speed = mix(0.25, 1.0, hash(vec2(lane, uSeed + 5.0))) * uSpeed;

    vec4 cur = texture(sTD2DInputs[0], uv);
    vec4 prev = texture(sTD2DInputs[1], uv - dir * speed * px);   // what slid into this pixel

    float l = luma(cur.rgb);
    float starts = step(uLo, l) * step(l, uHi);

    // a new streak starts at full height, a lane-random jitter makes neighbour bars uneven (the relief)
    float jitter = 0.75 + 0.25 * hash(vec2(lane, uSeed + 9.0));
    float hNew = mix(cur.a * 0.5, jitter, starts);

    // the streak keeps going while it is taller than what is under it now
    float hOld = prev.a * uHold;
    // a living streak paints over everything in its lane; only a taller new start can cut it
    bool keep = on > 0.5 && hOld > 0.04 && (starts < 0.5 || hOld > hNew);

    vec4 outc = keep ? vec4(prev.rgb, hOld) : vec4(cur.rgb, hNew * on + cur.a * 0.4 * (1.0 - on));
    fragColor = TDOutputSwizzle(clamp(outc, 0.0, 1.0));
}
