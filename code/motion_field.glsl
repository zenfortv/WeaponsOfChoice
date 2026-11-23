// What the player does to the motion vectors. Same grid as motion_search.
// Input 0 live vectors, input 1 this shader's previous output.
// Output xy: vectors the picture is moved by. zw: the measured vectors, used for the residual.

uniform float uGain;      // vector length
uniform float uHold;      // 1 = keep repeating the stored vectors (bloom)
uniform float uTrail;     // strong vectors linger after the motion has stopped
uniform float uMerge;     // blocks per side of a macroblock: 1, 2, 4, 8
uniform float uShatter;   // random vectors on a third of the blocks
uniform float uSeed;
uniform float uTarget;    // 0 everything, 1 only what moves, 2 only what is still
uniform float uCut;       // the frame of a cut has no usable vectors
uniform vec2  uPush;      // left stick: drag the whole picture, UV per frame
uniform vec2  uTwist;     // right stick: x spin, y zoom

out vec4 fragColor;

float hash(vec2 p)
{
    vec3 q = fract(vec3(p.xyx) * 0.1031);
    q += dot(q, q.yzx + 33.33);
    return fract((q.x + q.y) * q.z);
}

void main()
{
    ivec2 size = textureSize(sTD2DInputs[0], 0);
    ivec2 cell = ivec2(gl_FragCoord.xy);
    int merge = max(int(uMerge), 1);
    ivec2 group = cell / merge;
    ivec2 lead = min(group * merge + merge / 2, size - 1);

    vec2 live = (uCut > 0.5) ? vec2(0.0) : texelFetch(sTD2DInputs[0], lead, 0).xy;
    vec2 stored = texelFetch(sTD2DInputs[1], lead, 0).xy;

    vec2 mv = live * uGain;

    if (uTarget > 0.5)
    {
        float moving = step(0.002, length(live));
        mv *= (uTarget < 1.5) ? moving : 1.0 - moving;
    }

    vec2 kept = stored * uTrail;
    if (dot(kept, kept) > dot(mv, mv)) mv = kept;
    mv = mix(mv, stored, uHold);

    vec2 c = (vec2(group) + 0.5) * float(merge) / vec2(size) - 0.5;
    float aspect = float(size.x) / float(size.y);
    vec2 global = uPush;
    global += uTwist.x * vec2(-c.y / aspect, c.x * aspect);
    global += uTwist.y * c;

    float roll = hash(vec2(group) + uSeed);
    if (roll < 0.33 * sign(uShatter))
    {
        float a = hash(vec2(group) + uSeed + 17.0) * 6.2832;
        mv += vec2(cos(a), sin(a)) * uShatter * 0.08;
    }

    fragColor = TDOutputSwizzle(vec4(mv + global, live));
}
