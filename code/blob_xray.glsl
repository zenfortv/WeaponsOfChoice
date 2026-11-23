// /fx_blob x-ray layer with its own feedback. Input 0: video. Input 1: last frame of this layer.
// Inverted luminance, pushed to blue, the bright bones near white; the old frame drifts outward a little
// and fades by uFeed, so moving shapes leave glowing ghosts.
uniform float uFeed;     // 0 no trail .. 0.97 long trail
out vec4 fragColor;

void main() {
    vec2 uv = vUV.st;
    vec3 v = texture(sTD2DInputs[0], uv).rgb;
    float x = 1.0 - dot(v, vec3(0.299, 0.587, 0.114));
    x = smoothstep(0.15, 1.0, x);
    vec3 col = vec3(0.10, 0.35, 1.0) * pow(x, 1.6) * 1.4 + vec3(0.75, 0.9, 1.0) * pow(x, 7.0);
    vec2 back = (uv - 0.5) * 0.996 + 0.5;
    vec3 prev = texture(sTD2DInputs[1], back).rgb * uFeed;
    fragColor = TDOutputSwizzle(vec4(max(col, prev), 1.0));
}
