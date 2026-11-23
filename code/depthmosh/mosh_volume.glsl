// Mosh VOLUME pass: turns a moshed picture that carries depth in alpha into something that looks
// sculpted - lit relief, thick smear walls, shadows in the folds and a little camera parallax.
// Goes right after /fx_mosh glsl_mosh (or after drag) and before null_out. One GLSL TOP, no Python.
// Input 0: mosh output, RGB colour, A depth (0 far, 1 near). See mosh_carry_depth.md.
// Input 1: motion field (glsl_field, xy = UV offset per frame), gives the direction of the smear walls.
//
// Knobs (all 0..1 unless noted), start values in brackets:
uniform float uRelief;    // how tall the depth is for the light [0.5]
uniform float uExtrude;   // length of the smear walls, 0 = off [0.4]
uniform float uLight;     // light angle 0..1 = full turn, put an LFO or the beat on it [0.15]
uniform float uShine;     // chrome highlight [0.6]
uniform float uShadow;    // darkness in folds and behind walls [0.5]
uniform float uFog;       // far things fade to black [0.4]
uniform vec2  uView;      // camera sway in UV, e.g. audio low * 0.01 [0,0]
uniform float uAmount;    // 0 = plain mosh, 1 = full volume [1]

out vec4 fragColor;

float depthAt(vec2 uv) { return texture(sTD2DInputs[0], clamp(uv, 0.0, 1.0)).a; }

void main()
{
    vec2 uv0 = vUV.st;
    vec2 px = uTDOutputInfo.res.xy;
    vec4 plain = texture(sTD2DInputs[0], uv0);

    // 1. Parallax: walk into the depth along the view shift until we hit the surface (12 steps, then
    //    a linear fix between the last two steps so there is no grain / stair steps).
    vec2 uv = uv0;
    if (dot(uView, uView) > 0.0)
    {
        const int STEPS = 12;
        vec2 stepUV = uView / float(STEPS);
        float layer = 1.0;
        float layerStep = 1.0 / float(STEPS);
        float d = depthAt(uv);
        float lastLayer = layer;
        float lastD = d;
        for (int i = 0; i < STEPS; i++)
        {
            if (d >= layer) break;
            lastLayer = layer; lastD = d;
            uv -= stepUV;
            layer -= layerStep;
            d = depthAt(uv);
        }
        float after = d - layer;
        float before = lastD - lastLayer;
        float w = after / min(after - before, -0.0001);
        uv = mix(uv, uv + stepUV, clamp(w, 0.0, 1.0));
    }

    vec4 c = texture(sTD2DInputs[0], clamp(uv, 0.0, 1.0));
    float h = c.a;

    // 2. Smear walls: look back along the motion. A nearer pixel there throws a wall over this one,
    //    coloured like that pixel but darker - this is what makes the smear look thick, like a slab.
    vec3 col = c.rgb;
    float wall = 0.0;
    vec2 mv = texture(sTD2DInputs[1], uv).xy;
    float mlen = length(mv);
    if (uExtrude > 0.0 && mlen > 1e-5)
    {
        vec2 dir = mv / mlen;
        float reach = uExtrude * 0.06;             // max wall length in UV
        for (int i = 1; i <= 10; i++)
        {
            float t = float(i) / 10.0;
            vec2 q = uv + dir * reach * t;
            vec4 s = texture(sTD2DInputs[0], clamp(q, 0.0, 1.0));
            // the wall top falls off with distance: a pixel t away must be t*... higher to cover us
            if (s.a - t * 0.5 > h + 0.02)
            {
                float shade = mix(0.85, 0.35, t);   // far down the wall = darker
                col = s.rgb * shade;
                h = s.a - t * 0.5;
                wall = 1.0 - t;
                break;
            }
        }
    }

    // 3. Normal from the depth (central differences, 2 px apart so mosh blocks don't speckle it)
    float hx = depthAt(uv + vec2(px.x * 2.0, 0.0)) - depthAt(uv - vec2(px.x * 2.0, 0.0));
    float hy = depthAt(uv + vec2(0.0, px.y * 2.0)) - depthAt(uv - vec2(0.0, px.y * 2.0));
    vec3 n = normalize(vec3(-hx * uRelief * 40.0, -hy * uRelief * 40.0, 1.0));
    if (wall > 0.0) n = normalize(vec3(-normalize(mv) * 0.8, 0.6));  // walls face along the smear

    // 4. Light: one key light turning around, chrome highlight, rim on steep edges
    float a = uLight * 6.2832;
    vec3 L = normalize(vec3(cos(a), sin(a), 0.9));
    vec3 V = vec3(0.0, 0.0, 1.0);
    float diff = max(dot(n, L), 0.0);
    float spec = pow(max(dot(reflect(-L, n), V), 0.0), 48.0) * uShine;
    float rim = pow(1.0 - n.z, 2.0) * 0.6;

    // 5. Folds: compare with the depth around (8 taps, 14 px) - lower than the neighbours = in shadow
    float around = 0.0;
    for (int i = 0; i < 8; i++)
    {
        float b = float(i) * 0.7854;
        around += depthAt(uv + vec2(cos(b), sin(b)) * px * 14.0);
    }
    around /= 8.0;
    float ao = 1.0 - clamp((around - h) * 4.0, 0.0, 1.0) * uShadow;

    vec3 lit = col * (0.35 + 0.85 * diff) * ao + spec * mix(vec3(1.0), col * 1.6, 0.7) + col * rim;   // highlight keeps the colour
    lit *= mix(1.0, 0.25 + 0.75 * h, uFog);   // far = darker

    vec3 outc = mix(plain.rgb, lit, uAmount);
    fragColor = TDOutputSwizzle(vec4(clamp(outc, 0.0, 1.0), 1.0));
}
