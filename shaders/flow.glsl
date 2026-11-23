// flow.glsl - pass 1 of the metal feedback loop
// state texture: rgb = last metal image, a = surface height
// in0 = previous state (feedback), in1 = seed noise (r)

uniform float uFeedback;   // 0..1  how much of the previous surface survives
uniform float uFlow;       // swirl strength
uniform float uZoom;       // zoom per frame (+ = in)
uniform float uRot;        // rotation per frame (rad)
uniform float uLightFeed;  // how much the reflections push the surface

out vec4 fragColor;

vec4 S(vec2 uv) { return texture(sTD2DInputs[0], uv); }

void main()
{
    vec2 uv = vUV.st;
    vec2 px = uTD2DInfos[0].res.xy;
    float aspect = uTD2DInfos[0].res.z / uTD2DInfos[0].res.w;

    // large-scale slope of the previous surface (12 px step) -> smooth, stable swirl
    vec2 o = px * 12.0;
    float hL = S(uv - vec2(o.x, 0.0)).a;
    float hR = S(uv + vec2(o.x, 0.0)).a;
    float hD = S(uv - vec2(0.0, o.y)).a;
    float hU = S(uv + vec2(0.0, o.y)).a;
    vec2 g = vec2(hR - hL, hU - hD);

    // liquid swirl: move along the contour lines, a bit down the slope
    vec2 flow = vec2(-g.y, g.x) + 0.15 * g;

    // global slow zoom + rotation around the centre (aspect correct)
    vec2 c = uv - 0.5;
    c.x *= aspect;
    float cs = cos(uRot), sn = sin(uRot);
    c = mat2(cs, -sn, sn, cs) * c;
    c *= (1.0 - uZoom);
    c.x /= aspect;
    // displacement in pixels, capped (CFL) so the advection stays stable
    vec2 d = flow * uFlow * 8.0;
    float dl = length(d);
    if (dl > 3.0) d *= 3.0 / dl;
    vec2 suv = c + 0.5 - d * px;

    // advected previous state + light smoothing (surface tension)
    vec4 prev = S(suv);
    // never let a bad pixel poison the loop
    if (any(isnan(prev)) || any(isinf(prev))) prev = vec4(0.0, 0.0, 0.0, 0.5);
    // 8-tap ring at 1.5 px: wide enough to kill filament ripples, keeps the shapes
    vec2 q = px * 1.5;
    float hn = 0.0;
    hn += S(suv + vec2( q.x, 0.0)).a + S(suv + vec2(-q.x, 0.0)).a;
    hn += S(suv + vec2(0.0,  q.y)).a + S(suv + vec2(0.0, -q.y)).a;
    hn += S(suv + q * vec2( 0.7,  0.7)).a + S(suv + q * vec2(-0.7,  0.7)).a;
    hn += S(suv + q * vec2( 0.7, -0.7)).a + S(suv + q * vec2(-0.7, -0.7)).a;
    hn *= 0.125;
    float h = mix(prev.a, hn, 0.75);

    // the reflected light feeds back into the shape: bright areas rise
    // wide, truly blurred light (mip level 5 = ~32 px) so it swells the metal
    // in broad bulges instead of pitting it. needs Input Smoothness = mipmap.
    vec3 lsum = textureLod(sTD2DInputs[0], suv, 5.0).rgb;
    float lum = dot(lsum, vec3(1.0 / 3.0));
    if (isnan(lum)) lum = 0.0;
    h += uLightFeed * (clamp(lum, 0.0, 2.0) - 0.4) * 0.006;

    // blend with the moving seed; Feedback 0 = mostly seed, 1 = long memory
    float keep = mix(0.5, 0.995, clamp(uFeedback, 0.0, 1.0));
    float seed = texture(sTD2DInputs[1], uv).r;
    h = mix(seed, h, keep);
    h = clamp(h, -0.5, 1.5);
    if (isnan(h)) h = seed;

    fragColor = TDOutputSwizzle(vec4(prev.rgb, h));
}
