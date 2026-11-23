// A P-frame decoder with the keyframes taken away.
//   picture = previous picture moved by the vectors + residual
//   residual = this source frame - previous source frame moved by the measured vectors
// Input 0 previous output, 1 source, 2 previous source, 3 motion field.

uniform vec2  uCells;     // macroblocks in the frame (width / 16, height / 16)
uniform float uMerge;
uniform float uRefresh;   // chance per frame that a macroblock is rebuilt from the source
uniform float uResidual;  // 0 = pixels only get pushed around
uniform float uChroma;    // how much of the residual reaches the colour, 0 = colours stay stuck
uniform float uQuant;     // 0 clean to 1 crushed residual
uniform float uLeak;      // the source seeps in everywhere
uniform float uCut;       // 1 = this is the I-frame being dropped
uniform float uFreeze;    // hold the frame
uniform float uSeed;
uniform vec4  uSplat;     // origin xy, how far the lock has spread, how far the clean wave has come back
uniform float uStop;      // 1 = the locked area stands still this frame
uniform float uShape;     // fixed for one splat, so its outline doesn't boil
uniform float uLiquid;
uniform float uParallax;  // DEPTH look: near pixels move further (0 = off)    // 0 hard macroblocks, 1 vectors flow smoothly between blocks

out vec4 fragColor;

const mat3 TO_YCC = mat3(
     0.299, -0.169,  0.500,
     0.587, -0.331, -0.419,
     0.114,  0.500, -0.081);
const mat3 TO_RGB = mat3(
     1.000,  1.000,  1.000,
     0.000, -0.344,  1.772,
     1.402, -0.714,  0.000);

float hash(vec2 p)
{
    vec3 q = fract(vec3(p.xyx) * 0.1031);
    q += dot(q, q.yzx + 33.33);
    return fract((q.x + q.y) * q.z);
}

float smoothNoise(vec2 p)
{
    vec2 i = floor(p);
    vec2 f = fract(p);
    f = f * f * (3.0 - 2.0 * f);
    return mix(mix(hash(i), hash(i + vec2(1, 0)), f.x),
               mix(hash(i + vec2(0, 1)), hash(i + vec2(1, 1)), f.x), f.y);
}

// Distance from the origin along a wet, uneven outline, with loose drops flung ahead of the front.
// The lock has reached a pixel when this is under uSplat.z.
float splatDistance(vec2 uv)
{
    vec2 aspect = vec2(uCells.x / uCells.y, 1.0);
    vec2 p = (uv - uSplat.xy) * aspect;
    float d = length(p);
    vec2 dir = p / max(d, 0.0001);
    vec2 q = uv * aspect + uShape;
    float edge = smoothNoise(dir * 2.2 + uShape) * 0.45
               + smoothNoise(q * 7.0) * 0.16
               + smoothNoise(q * 23.0) * 0.06;
    d += edge * min(1.0, d * 3.0);

    vec2 g = (uv * aspect + uShape) * 26.0;
    vec2 id = floor(g);
    float roll = hash(id + 3.0);
    if (roll < 0.1)
    {
        vec2 centre = vec2(hash(id + 5.0), hash(id + 9.0)) * 0.5 + 0.25;
        float size = 0.12 + 0.3 * hash(id + 13.0);
        if (length(fract(g) - centre) < size) d -= 0.22 + 0.3 * hash(id + 21.0);
    }
    return d;
}

void main()
{
    vec2 uv = vUV.st;
    vec4 lastA = texelFetch(sTD2DInputs[0], ivec2(gl_FragCoord.xy), 0);
    vec3 last = lastA.rgb;

    float reach = splatDistance(uv);
    bool locked = uSplat.z > 0.0 && reach < uSplat.z;
    if (uSplat.w > 0.0 && reach < uSplat.w - 0.5) locked = false;   // drops can reach -0.5
    bool still = uFreeze > 0.5 || (locked && uStop > 0.5);

    int merge = max(int(uMerge), 1);
    ivec2 cell = ivec2(uv * uCells);
    ivec2 group = cell / merge;
    ivec2 fieldSize = textureSize(sTD2DInputs[3], 0);
    vec4 field = texelFetch(sTD2DInputs[3], min(cell, fieldSize - 1), 0);
    if (uLiquid > 0.0)
    {
        vec2 at = clamp(uv * uCells - 0.5, vec2(0.0), vec2(fieldSize - 2));
        ivec2 o = ivec2(at);
        vec2 f = at - vec2(o);
        vec4 flow = mix(mix(texelFetch(sTD2DInputs[3], o, 0), texelFetch(sTD2DInputs[3], o + ivec2(1, 0), 0), f.x),
                        mix(texelFetch(sTD2DInputs[3], o + ivec2(0, 1), 0), texelFetch(sTD2DInputs[3], o + ivec2(1, 1), 0), f.x), f.y);
        field = mix(field, flow, uLiquid);
    }

    vec4 srcA = texture(sTD2DInputs[1], uv);
    vec3 source = srcA.rgb;
    float dHere = texture(sTD2DInputs[0], uv).a;
    vec2 move = field.xy * mix(1.0, 0.3 + 1.4 * dHere, uParallax);
    vec4 pred = texture(sTD2DInputs[0], clamp(uv + move, 0.0, 1.0));
    vec3 predicted = pred.rgb;
    float depth = pred.a;

    vec3 residual = vec3(0.0);
    if (uCut < 0.5)
    {
        // Only the average of each 8x8 block, like keeping the DC term of the DCT.
        // Per-pixel residuals carry the footage's noise and it adds up to black over time.
        vec2 pixel = vec2(1.0) / vec2(textureSize(sTD2DInputs[1], 0));
        vec2 corner = floor(uv / (pixel * 8.0)) * pixel * 8.0;
        vec3 now = vec3(0.0);
        vec3 then = vec3(0.0);
        for (int i = 0; i < 4; i++)
        {
            vec2 tap = corner + pixel * vec2(float(i & 1) * 4.0 + 2.0, float(i >> 1) * 4.0 + 2.0);
            now += texture(sTD2DInputs[1], tap).rgb;
            then += texture(sTD2DInputs[2], clamp(tap + field.zw, 0.0, 1.0)).rgb;
        }
        residual = TO_YCC * (now - then) * 0.25;

        float q = mix(48.0, 3.0, uQuant);
        float dead = 0.02 + uQuant * 0.12;
        residual = round(residual * q) / q;
        residual *= step(dead, abs(residual.x) + abs(residual.y) + abs(residual.z));
        // Inside the lock only soft change gets through. Hard edges and flashes in the source
        // are what read as glitch; the vectors carry the picture, like wet paint.
        if (locked) residual *= 1.0 - smoothstep(0.06, 0.2, abs(residual.x));
        residual *= vec3(uResidual, uResidual * uChroma, uResidual * uChroma);
        residual = TO_RGB * residual;
    }

    vec3 picture = predicted + residual;

    if (!locked)
    {
        picture = mix(picture, source, uLeak);
        depth = mix(depth, srcA.a, uLeak);
        if (hash(vec2(group) + uSeed) < uRefresh) { picture = source; depth = srcA.a; }
    }

    if (still) { picture = last; depth = lastA.a; }

    fragColor = TDOutputSwizzle(vec4(clamp(picture, 0.0, 1.0), clamp(depth, 0.0, 1.0)));
}
