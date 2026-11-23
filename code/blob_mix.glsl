// /fx_blob final: video outside the blobs, the green metal 'double' inside, green bloom spilling out,
// boxes + labels trail. Inputs: 0 video, 1 masked double (alpha = inside), 2 its blur (bloom), 3 boxes + labels trail.
uniform float uGlow;     // bloom strength 0..3
out vec4 fragColor;

void main() {
    vec2 uv = vUV.st;
    vec4 v = texture(sTD2DInputs[0], uv);
    vec4 x = texture(sTD2DInputs[1], uv);
    vec3 glow = texture(sTD2DInputs[2], uv).rgb * vec3(0.5, 1.2, 0.6);   // green bloom
    vec3 trail = texture(sTD2DInputs[3], uv).rgb;
    vec3 c = mix(v.rgb, x.rgb, x.a) + glow * uGlow + trail;
    fragColor = TDOutputSwizzle(vec4(c, 1.0));
}
