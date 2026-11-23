// /fx_blob glsl_top (MetalShow.57): the blob layer alone (metal double inside the boxes, its bloom, boxes + labels
// trail) with alpha, premultiplied. Root puts it back on top AFTER the master grade, so the blob keeps its own Color
// instead of taking the video's colours. Inputs: 1 masked double (alpha = inside), 2 its blur, 3 boxes + labels trail,
// 4 mask_screens (red = which screens, already times the effect's mix). Input 0 (video) unused, kept for the size.
uniform float uGlow;     // bloom strength 0..3
uniform float uOn;       // 0 during BLACK
out vec4 fragColor;

void main() {
    vec2 uv = vUV.st;
    vec4 x = texture(sTD2DInputs[1], uv);
    vec3 glow = texture(sTD2DInputs[2], uv).rgb * uGlow;
    vec3 trail = texture(sTD2DInputs[3], uv).rgb;
    float m = texture(sTD2DInputs[4], uv).r * uOn;
    vec3 add = glow + trail;
    float a = clamp(max(x.a, max(add.r, max(add.g, add.b))), 0.0, 1.0);
    vec3 c = x.rgb * x.a + add;
    fragColor = TDOutputSwizzle(vec4(c * m, a * m));
}
