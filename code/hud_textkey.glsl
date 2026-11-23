// /hud_top (MetalShow.55): keeps the HUD's coloured parts (weapon title, red boxes, tabs, ticker) readable.
// The HUD's CRT shader leaves only the neon elements saturated, so a saturation key on the finished HUD
// (phosphor, scanlines, glitch included) cuts them out; they go back on top after every effect and the grade,
// with a dark halo behind them so red text stays readable on a red-graded picture.
// uK.x = opacity (how much HUD is on screen, 0 in BLACK), uK.y = saturation threshold, uK.z = halo darkness
uniform vec3 uK;
out vec4 fragColor;

float key(vec2 uv)
{
    vec3 rgb = max(texture(sTD2DInputs[0], uv).rgb, 0.0);
    float mx = max(rgb.r, max(rgb.g, rgb.b));
    float mn = min(rgb.r, min(rgb.g, rgb.b));
    float sat = mx > 0.001 ? (mx - mn) / mx : 0.0;
    return smoothstep(uK.y, uK.y + 0.2, sat) * smoothstep(0.08, 0.3, mx);
}

void main()
{
    vec2 uv = vUV.st;
    vec3 rgb = max(texture(sTD2DInputs[0], uv).rgb, 0.0);
    float a = key(uv);
    vec2 px = 1.0 / uTD2DInfos[0].res.zw;
    float halo = 0.0;
    for (int i = 0; i < 8; i++) {
        float ang = float(i) * 0.785398;
        vec2 d = vec2(cos(ang), sin(ang));
        halo = max(halo, key(uv + d * px * 3.0));
        halo = max(halo, key(uv + d * px * 7.0) * 0.6);
    }
    float alpha = max(a, halo * uK.z) * uK.x;
    fragColor = TDOutputSwizzle(vec4(rgb * a * uK.x, alpha));     // premultiplied, for an Over
}
