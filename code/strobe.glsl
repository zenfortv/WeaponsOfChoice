// /fx_strobe: white flashes over the video.
// uFlash.x = rate square (0/1), .y = kick flash, .z = action flash, .w = intensity. uBlack = Action2 blackout.
uniform vec4 uFlash;
uniform float uBlack;
out vec4 fragColor;

void main() {
    vec4 c = texture(sTD2DInputs[0], vUV.st);
    float f = max(max(uFlash.x, uFlash.y), uFlash.z) * uFlash.w;
    c.rgb = mix(c.rgb, vec3(1.0), clamp(f, 0.0, 1.0));
    c.rgb *= 1.0 - clamp(uBlack, 0.0, 1.0);
    fragColor = TDOutputSwizzle(c);
}
