// WeaponsHUD - early 2000s CRT finish (MetalShow copy: code/hud_crt.glsl, keeps the scheme colours)
// input 0: 640x360 HUD composite (sampled nearest = chunky pixels)
// uGlitch 0..1 burst on object change, uTime seconds for noise
uniform float uGlitch;
uniform float uTime;
uniform float uScan;     // scanline strength 0..1

out vec4 fragColor;

float hash(vec2 p){ return fract(sin(dot(p, vec2(12.9898, 78.233))) * 43758.5453); }

void main()
{
    vec2 uv = vUV.st;
    float t = floor(uTime * 24.0);              // 24 fps "steppy" noise

    // glitch: horizontal band tearing
    float band = floor(uv.y * 45.0);
    float tear = (hash(vec2(band, t)) - 0.5) * 0.12 * uGlitch * step(0.6, hash(vec2(band * 1.7, t)));
    uv.x += tear;

    // colour bleed (RGB split), stronger during glitch
    float split = (1.0 / 640.0) * (1.0 + 6.0 * uGlitch);
    float r = texture(sTD2DInputs[0], uv + vec2(split, 0.0)).r;
    float g = texture(sTD2DInputs[0], uv).g;
    float b = texture(sTD2DInputs[0], uv - vec2(split, 0.0)).b;
    vec3 col = vec3(r, g, b);

    // scanlines: every 2nd output row darker (960 -> 1920 = 2x)
    float line = mod(gl_FragCoord.y, 2.0) < 1.0 ? 1.0 - 0.35 * uScan : 1.0;
    col *= line;

    // static noise, more during glitch
    float n = hash(floor(gl_FragCoord.xy / 2.0) + t);
    col += (n - 0.5) * (0.06 + 0.5 * uGlitch);

    // vignette
    vec2 d = vUV.st - 0.5;
    col *= 1.0 - dot(d, d) * 0.9;

    // black and white: luminance only (RGB split now reads as a soft double edge)
    float l = dot(col, vec3(0.299, 0.587, 0.114));
    vec3 outc = vec3(clamp(l, 0.0, 1.0));

    // MetalShow.43: strongly coloured HUD parts (3D cloud, tab bars, weapon name in the POP colour scheme) keep
    // their colour. Saturation is read on the centre sample so the RGB split never tints white text edges.
    vec3 c0 = texture(sTD2DInputs[0], uv).rgb;
    float sat = max(c0.r, max(c0.g, c0.b)) - min(c0.r, min(c0.g, c0.b));
    float keep = smoothstep(0.2, 0.4, sat);
    vec3 tint = c0 * line * (1.0 - dot(d, d) * 0.9) + (n - 0.5) * (0.06 + 0.5 * uGlitch);
    outc = mix(outc, clamp(tint, 0.0, 1.0), keep);

    // neon layer (input 1: red kills/wars + ochre production, with glow, on black) - the only colour on screen
    vec3 neon = texture(sTD2DInputs[1], uv).rgb * line;
    float m = clamp(max(neon.r, max(neon.g, neon.b)) * 1.2, 0.0, 1.0);
    outc = outc * (1.0 - 0.75 * m) + neon * 1.15;

    fragColor = TDOutputSwizzle(vec4(clamp(outc, 0.0, 1.0), 1.0));
}
