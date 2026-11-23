// WeaponsHUD - phosphor display pass (after crt.glsl)
// input 0: current CRT frame, input 1: previous output (feedback), input 2: blurred current (bloom)
uniform float uDecay;    // afterglow persistence 0..0.95
uniform float uBloom;    // glow amount
uniform float uTime;     // seconds
uniform float uFlicker;  // 0..0.1
uniform float uRoll;     // random glitch amount 0..1 (vertical jump)

out vec4 fragColor;

float hash(float n) { return fract(sin(n) * 43758.5453); }

void main()
{
    vec2 uv = vUV.st;

    // vertical hold slip during random glitches: whole image jumps a bit
    float jump = (hash(floor(uTime * 20.0)) - 0.5) * 0.06 * uRoll;
    vec2 suv = vec2(uv.x, fract(uv.y + jump));

    vec3 cur  = texture(sTD2DInputs[0], suv).rgb;
    vec3 prev = texture(sTD2DInputs[1], uv).rgb;
    vec3 glow = texture(sTD2DInputs[2], suv).rgb;

    // phosphor afterglow: bright pixels decay slowly instead of switching off
    vec3 c = max(cur, prev * uDecay);
    c += glow * uBloom;

    // slow refresh band rolling down the screen
    float p = fract(uv.y + uTime * 0.11);
    float band = smoothstep(0.0, 0.05, p) * (1.0 - smoothstep(0.05, 0.14, p));
    c *= 1.0 + 0.07 * band;

    // tube flicker
    c *= 1.0 - uFlicker * hash(floor(uTime * 30.0));

    fragColor = TDOutputSwizzle(vec4(clamp(c, 0.0, 1.0), 1.0));
}
