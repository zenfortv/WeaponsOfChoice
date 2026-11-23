// out.glsl - display only: opaque alpha, gentle highlight shoulder, b/w
out vec4 fragColor;

void main()
{
    vec3 c = texture(sTD2DInputs[0], vUV.st).rgb;
    float l = max(dot(c, vec3(1.0 / 3.0)), 0.0);
    l = 1.0 - exp(-1.8 * l);           // filmic shoulder: hot whites keep their detail
    l = clamp(l, 0.0, 1.0);
    fragColor = TDOutputSwizzle(vec4(vec3(l), 1.0));
}
