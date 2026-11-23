// /fx_boom glsl_strobe (MetalShow.53): the strobe is never plain white. On each flash the picture turns into an
// effect frame that follows the image, and the flash chases across the 3 screens from one side:
// flash 1 = screen on that side, 2 = middle, 3 = other side, 4 = all three. Every chase changes effect and side.
// Effects: 0 LIQUID CHROME (luminance folded into metal bands), 1 EDGE GLOW, 2 BURN (hot highlights, black rest).
// uS.x = flash on (0/1), uS.y = count of flashes, uS.z = 1 when the BOOM/strobe is active.
// uB = screen bounds (/crop_screen2 cropleft, cropright), the same ones the kantan crops use.
uniform vec4 uS;
uniform vec2 uB;
out vec4 fragColor;

float lum(vec3 c) { return dot(max(c, 0.0), vec3(0.299, 0.587, 0.114)); }
float L(vec2 uv) { return lum(texture(sTD2DInputs[0], uv).rgb); }

void main()
{
    vec2 uv = vUV.st;
    vec4 src = texture(sTD2DInputs[0], uv);
    int n = int(uS.y + 0.5);
    int step4 = n % 4;
    int chase = n / 4;
    int scr = uv.x < uB.x ? 0 : (uv.x < uB.y ? 1 : 2);
    int k = step4;
    if (chase % 2 == 1 && k < 3) k = 2 - k;          // every other chase starts from the other side
    float a = uS.x * uS.z * ((k == 3 || k == scr) ? 1.0 : 0.0);
    if (a <= 0.0) { fragColor = TDOutputSwizzle(src); return; }

    vec2 px = 1.5 / uTD2DInfos[0].res.zw;
    float l = lum(src.rgb);
    float gx = L(uv + vec2(px.x, 0)) - L(uv - vec2(px.x, 0));
    float gy = L(uv + vec2(0, px.y)) - L(uv - vec2(0, px.y));
    float e = clamp(length(vec2(gx, gy)) * 4.0, 0.0, 1.0);

    int mode = chase % 3;
    vec3 fx;
    if (mode == 0) {                       // liquid chrome
        float b = 0.5 + 0.5 * cos(l * 16.0 + e * 5.0);
        fx = vec3(pow(b, 2.5) * 1.4 + e * 0.6);
    } else if (mode == 1) {                // edge glow
        fx = vec3(pow(e, 0.7) * 1.6) + src.rgb * 0.15;
    } else {                               // burn
        float h = smoothstep(0.15, 0.75, l);
        fx = vec3(pow(h, 0.6) * 1.5) + vec3(e);
    }
    fragColor = TDOutputSwizzle(vec4(fx, 1.0));
}
