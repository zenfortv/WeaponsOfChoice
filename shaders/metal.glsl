// metal.glsl - pass 2 of the metal feedback loop (still inside the loop)
// turns the height (a) into a polished chrome surface reflecting a b/w studio
// in0 = output of flow.glsl. Output: rgb = metal image (HDR), a = height

uniform float uBright;    // light intensity; result is fed back into the loop
uniform float uRelief;    // how steep the surface reads
uniform float uFeedback;  // 0..1
uniform float uTrails;    // how much old highlights linger
uniform float uTime;

out vec4 fragColor;

float H(vec2 uv) { return texture(sTD2DInputs[0], uv).a; }

mat2 rot(float a) { float c = cos(a), s = sin(a); return mat2(c, -s, s, c); }

// soft-edged box mask: 1 inside |p| < size, edge width e
float box(vec2 p, vec2 size, float e)
{
    vec2 d = abs(p) - size;
    return smoothstep(e, 0.0, max(d.x, d.y));
}

// black-and-white photo studio, seen in direction r
float env(vec3 r, float t)
{
    r.xy = rot(t * 0.13) * r.xy;
    r.xz = rot(sin(t * 0.21) * 0.5) * r.xz;
    r.yz = rot(cos(t * 0.17) * 0.4) * r.yz;

    // dark room with a soft ceiling sweep -> gradients roll across the curves
    float sweep = smoothstep(-1.0, 1.0, r.y);
    float e = 0.01 + 0.22 * sweep * sweep;
    e += 0.08 * exp(-6.0 * dot(r.xy, r.xy));                          // faint fill straight on

    // big top softbox: bright centre falling off to its edges
    vec2 p = r.xy - vec2(0.0, 0.6);
    float sb = box(p, vec2(0.55, 0.11), 0.04);
    e += 1.5 * sb * (0.55 + 0.45 * (1.0 - abs(p.x) / 0.55));

    // two thin vertical strips (crisp lines = the "polished" read)
    e += 1.8 * box(r.xy - vec2( 0.74, 0.05), vec2(0.03, 0.55), 0.01);
    e += 1.8 * box(r.xy - vec2(-0.74, 0.05), vec2(0.03, 0.55), 0.01);

    // floor bounce card, dimmer and soft
    e += 0.45 * box(r.xy - vec2(0.0, -0.72), vec2(0.45, 0.06), 0.06);

    // ring light -> thin rims on the steepest edges
    float ring = abs(length(r.xy) - 0.93) - 0.01;
    e += 1.0 * smoothstep(0.02, 0.0, ring);
    return e;
}

void main()
{
    vec2 uv = vUV.st;
    vec2 px = uTD2DInfos[0].res.xy;
    vec4 st = texture(sTD2DInputs[0], uv);
    float aspect = uTD2DInfos[0].res.z / uTD2DInfos[0].res.w;

    // normal from the height field (central differences, 1.5 px)
    vec2 o = px * 2.5;
    float hL = H(uv - vec2(o.x, 0.0)), hR = H(uv + vec2(o.x, 0.0));
    float hD = H(uv - vec2(0.0, o.y)), hU = H(uv + vec2(0.0, o.y));
    vec3 n = normalize(vec3(-(hR - hL) * uRelief, -(hU - hD) * uRelief, 1.0));

    // cavity: valleys get darker (gives the metal its depth)
    float lap = (hL + hR + hD + hU) * 0.25 - st.a;
    float cavity = clamp(1.0 - lap * uRelief * 0.6, 0.25, 1.15);

    // camera looks straight down at the surface
    vec3 V = vec3(0.0, 0.0, 1.0);
    vec3 R = reflect(-V, n);

    // chrome Fresnel (Schlick, F0 high for polished metal)
    float ndv = clamp(dot(n, V), 0.0, 1.0);
    float F = 0.82 + 0.18 * pow(1.0 - ndv, 5.0);

    float col = env(R, uTime) * F;

    // two moving point lights -> sharp mirror glints
    vec3 P = vec3((uv.x - 0.5) * aspect, uv.y - 0.5, 0.0);
    vec3 L1 = vec3(0.55 * cos(uTime * 0.7), 0.35 * sin(uTime * 0.9), 0.45);
    vec3 L2 = vec3(-0.5 * sin(uTime * 0.53), 0.4 * cos(uTime * 0.61), 0.6);
    for (int i = 0; i < 2; i++) {
        vec3 l = normalize((i == 0 ? L1 : L2) - P);
        vec3 h = normalize(l + V);
        float nh = clamp(dot(n, h), 0.0, 1.0);
        col += (6.0 * pow(nh, 900.0) + 0.25 * pow(nh, 60.0)) * F;
    }

    col *= cavity * uBright;

    // previous highlights linger a little (scaled by feedback amount)
    vec3 outc = mix(vec3(col), st.rgb, uTrails * clamp(uFeedback, 0.0, 1.0));

    fragColor = TDOutputSwizzle(vec4(outc, st.a));
}
