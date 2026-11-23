// The whole panel in one pass, from knobs.py's data image, with the Text TOP on top.
// Input 0: row 0 x, y, radius or half width, position; row 1 kind (0 knob, 1 button), lit, half height, pad.
// Input 1: labels. The panel is alive: audio meters, and lime blocks sparking on the hits.

uniform vec4 uLive;     // low, mid, high, 1 while View is held on the pad
uniform float uSeed;

out vec4 fragColor;

const vec3 BACK  = vec3(0.035, 0.085, 0.095);
const vec3 BACK2 = vec3(0.045, 0.125, 0.125);
const vec3 TRACK = vec3(0.105, 0.225, 0.245);
const vec3 BODY  = vec3(0.055, 0.125, 0.140);
const vec3 AQUA  = vec3(0.420, 0.880, 0.950);
const vec3 SEA   = vec3(0.210, 0.800, 0.640);
const vec3 LIME  = vec3(0.740, 1.000, 0.260);
const vec3 STRIP = vec3(0.022, 0.058, 0.066);
const float START = 2.35619449;   // the arc runs 135 degrees either side of twelve o'clock
const float SWEEP = 4.71238898;

float inside(float d, float r)
{
	return smoothstep(r + 0.7, r - 0.7, d);
}

float box(vec2 d, vec2 half_size)
{
	vec2 q = abs(d) - half_size;
	return inside(max(q.x, q.y), 0.0);
}

float hash(vec2 p)
{
	vec3 q = fract(vec3(p.xyx) * 0.1031);
	q += dot(q, q.yzx + 33.33);
	return fract((q.x + q.y) * q.z);
}

vec3 knob(vec3 col, vec2 d, float r, float position, float lit, float pad)
{
	col = mix(col, STRIP, box(d - vec2(0.0, -r - 14.0), vec2(r + 12.0, 8.0)));
	float dist = length(d);
	if (dist < r + 12.0) col += SEA * 0.05 * smoothstep(r + 12.0, r, dist) * (lit + pad * uLive.w * 3.0);
	if (dist > r + 2.0) return col;
	float t = (atan(d.x, d.y) + START) / SWEEP;
	float ring = inside(abs(dist - r * 0.92), r * 0.06);
	if (t >= 0.0 && t <= 1.0)
	{
		vec3 on = lit > 0.5 ? mix(SEA, AQUA, t) : mix(AQUA, SEA, 0.35) * 0.72;
		col = mix(col, t <= position ? on : TRACK, ring);
	}
	col = mix(col, BODY, inside(dist, r * 0.76));
	col += AQUA * 0.05 * smoothstep(r * 0.76, 0.0, length(d - vec2(-r, r) * 0.25));
	float at = position * SWEEP - START;
	vec2 hand = vec2(sin(at), cos(at));
	float across = abs(dot(d, vec2(hand.y, -hand.x)));
	float along = dot(d, hand);
	if (along > r * 0.58 && along < r * 0.76) col = mix(col, LIME, inside(across, 1.3));
	return col;
}

vec3 button(vec3 col, vec2 d, vec2 half_size, float lit)
{
	col = mix(col, lit > 0.5 ? AQUA : TRACK, box(d, half_size));
	return mix(col, lit > 0.5 ? mix(SEA, AQUA, 0.3) * 0.55 : BODY, box(d, half_size - 1.0));
}

// Three segmented meters across the top, in macroblocks
vec3 meters(vec3 col, vec2 px, vec2 res)
{
	const float CELL = 8.0;
	float left = 76.0;
	float width = res.x - left - 14.0;
	vec2 cell = floor((px - vec2(left, res.y - 34.0)) / CELL);
	if (px.x < left || px.x > left + width || cell.y < 0.0 || cell.y > 2.0) return col;
	float band = 2.0 - cell.y;
	float level = band < 0.5 ? uLive.x : (band < 1.5 ? uLive.y : uLive.z);
	vec2 f = fract((px - vec2(left, res.y - 34.0)) / CELL);
	if (f.x > 0.82 || f.y > 0.72) return col;
	float x = (cell.x + 0.5) * CELL / width;
	vec3 tone = band < 0.5 ? SEA : (band < 1.5 ? AQUA : mix(SEA, LIME, 0.6));
	return mix(col, x < level ? mix(tone, LIME, smoothstep(0.75, 1.0, x)) : TRACK * 0.8, 1.0);
}

void main()
{
	vec2 res = uTDOutputInfo.res.zw;
	vec2 px = vUV.st * res;
	vec3 col = mix(BACK, BACK2, vUV.t * 0.7 + 0.15 * sin(vUV.s * 3.1));

	// Slight artefacts: small lime macroblocks that flicker in the background with the highs
	vec2 grid = floor(px / 8.0);
	float rare = hash(grid + floor(uSeed * 0.25));
	float spark = uLive.z * 0.018 + uLive.x * 0.006 + 0.0006;
	if (rare < spark) col = mix(col, LIME, 0.22 + 0.3 * uLive.z);

	col = meters(col, px, res);

	int n = textureSize(sTD2DInputs[0], 0).x;
	for (int i = 0; i < n; i++) {
		vec4 a = texelFetch(sTD2DInputs[0], ivec2(i, 0), 0);
		vec4 b = texelFetch(sTD2DInputs[0], ivec2(i, 1), 0);
		vec2 d = px - a.xy;
		col = b.x < 0.5 ? knob(col, d, a.z, a.w, b.y, b.w) : button(col, d, vec2(a.z, b.z), b.y);
	}
	vec4 words = texture(sTD2DInputs[1], vUV.st);
	col = col * (1.0 - words.a) + words.rgb;
	fragColor = TDOutputSwizzle(vec4(col, 1.0));
}
