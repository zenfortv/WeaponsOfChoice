// /drop glsl_drop (MetalShow.68): the DROP fade with a ghost and the strobe still working.
// out = live faded by the drop + a faint ghost of the frame frozen at the press, and while black the
// strobe (PLAY LB / BOOM) flashes effect frames of that frozen picture, same chase across the 3 screens
// as /fx_boom glsl_strobe (boom_strobe.glsl).
// Input 0: live picture (sw_hudtop). Input 1: frozen frame (cache_drop, holds while Drop is on).
uniform float uD;      // drop amount 0 live .. 1 black (null_drop, lagged)
uniform float uGhost;  // how bright the ghost stays in the black, 0..0.5
uniform vec4  uS;      // x flash on, y flash count, z strobe active (same as glsl_strobe)
uniform vec2  uB;      // screen bounds (crop_screen2 cropleft, cropright)
uniform float uStyle;  // MetalShow.70 transition: 0 fade, 1 burn, 2 luma key, 3 difference
uniform float uPunch;  // 0..1 dolly punch: brightness + contrast while the dolly runs
out vec4 fragColor;

float lum(vec3 c) { return dot(max(c, 0.0), vec3(0.299, 0.587, 0.114)); }
float L(vec2 uv) { return lum(texture(sTD2DInputs[1], uv).rgb); }

void main()
{
    vec2 uv = vUV.st;
    vec4 live = texture(sTD2DInputs[0], uv);
    vec4 held = clamp(texture(sTD2DInputs[1], uv), 0.0, 1.0);   // the picture can be HDR (>1), the ghost must stay dim

    // ghost: dark, a bit crushed so only the shapes stay, like a shadow of the last picture
    vec3 ghost = pow(max(held.rgb, 0.0), vec3(1.4)) * uGhost;

    // strobe flash on the frozen picture, chasing screen 1 / 2 / 3 / all like the boom strobe
    int n = int(uS.y + 0.5);
    int k = n % 4;
    int chase = n / 4;
    int scr = uv.x < uB.x ? 0 : (uv.x < uB.y ? 1 : 2);
    if (chase % 2 == 1 && k < 3) k = 2 - k;
    float a = uS.x * uS.z * ((k == 3 || k == scr) ? 1.0 : 0.0);
    vec3 flash = vec3(0.0);
    if (a > 0.0)
    {
        vec2 px = 1.5 / uTD2DInfos[1].res.zw;
        float l = lum(held.rgb);
        float e = clamp(length(vec2(L(uv + vec2(px.x, 0)) - L(uv - vec2(px.x, 0)),
                                    L(uv + vec2(0, px.y)) - L(uv - vec2(0, px.y)))) * 4.0, 0.0, 1.0);
        int mode = chase % 3;
        if (mode == 0)      flash = vec3(pow(0.5 + 0.5 * cos(l * 16.0 + e * 5.0), 2.5) * 1.4 + e * 0.6);
        else if (mode == 1) flash = vec3(pow(e, 0.7) * 1.6) + held.rgb * 0.15;
        else                flash = vec3(pow(smoothstep(0.15, 0.75, l), 0.6) * 1.5) + vec3(e);
    }
    vec3 dark = max(ghost, flash);
    // the live picture goes away in the chosen style (and comes back the same way, uD running backwards)
    float t = clamp(uD * 1.08, 0.0, 1.08);
    float l = lum(min(live.rgb, 1.0));
    vec3 lv;
    int st = int(uStyle + 0.5);
    if (st == 1) {                       // BURN: dark parts burn away first, a hot rim eats into the bright ones
        float keep = smoothstep(t - 0.04, t, l);
        float rim = keep * (1.0 - smoothstep(t, t + 0.14, l)) * step(0.001, uD);
        lv = live.rgb * keep * (1.0 - rim) + vec3(1.6, 0.75, 0.25) * rim * 1.5 + vec3(1.0) * rim * rim * 0.8;
    } else if (st == 2) {                // LUMA KEY: hard cut-out, only the brightest shapes survive to the end
        lv = live.rgb * step(t, l) * (1.0 + 2.0 * uD);
    } else if (st == 3) {                // DIFFERENCE: the picture flips negative and collapses into black
        lv = abs(live.rgb - vec3(min(t, 1.0))) * max(0.0, 1.0 - t * t);
    } else {
        lv = live.rgb * max(0.0, 1.0 - 1.02 * uD);
    }
    vec3 c = lv * step(uD, 0.999) + dark * uD;

    // dolly punch: lift + contrast around mid grey, then a little bloom of the highlights
    if (uPunch > 0.0) {
        vec3 k = (c - 0.5) * (1.0 + 1.2 * uPunch) + 0.5 + 0.25 * uPunch;
        c = max(k, 0.0) + max(c - 0.7, 0.0) * 1.5 * uPunch;
    }
    fragColor = TDOutputSwizzle(vec4(c, live.a));
}
