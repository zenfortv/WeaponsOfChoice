// Panel change flash (MetalShow.42): a lime outline around every control whose value just changed (AUTO, pad,
// mouse) or whose pulse AUTO just fired, fading over ~1.5 s. Small pass on top of the finished panel so the big
// panel shader still cooks only when something changes.
// Input 0: the panel. Input 1: script_data; rows 3-4 hold up to 16 recent changes:
//   row 3 = x, y, radius or half width, change time; row 4 = kind (0 knob, 1 button), half height.

uniform float uTime;

out vec4 fragColor;

const vec3 LIME = vec3(0.740, 1.000, 0.260);

void main()
{
	vec2 res = uTDOutputInfo.res.zw;
	vec2 px = vUV.st * res;
	vec4 col = texture(sTD2DInputs[0], vUV.st);
	float glow = 0.0;
	for (int i = 0; i < 16; i++) {
		vec4 a = texelFetch(sTD2DInputs[1], ivec2(i, 3), 0);
		float dt = uTime - a.w;
		if (dt < 0.0 || dt > 1.6) continue;
		vec4 b = texelFetch(sTD2DInputs[1], ivec2(i, 4), 0);
		float g = exp(-dt * 2.2) * (1.0 - smoothstep(1.2, 1.6, dt));
		float d;
		if (b.x < 0.5) {
			d = length(px - a.xy) - (a.z + 6.0);
		} else {
			vec2 q = abs(px - a.xy) - vec2(a.z + 4.0, b.y + 4.0);
			d = max(q.x, q.y);
		}
		float ring = smoothstep(2.6, 0.6, abs(d));
		float halo = smoothstep(14.0, 0.0, abs(d)) * 0.25;
		glow = max(glow, (ring + halo) * g);
	}
	col.rgb = mix(col.rgb, LIME, clamp(glow, 0.0, 1.0));
	fragColor = TDOutputSwizzle(col);
}
