// Show monitor (MetalShow.42), right of the output preview in /perform: audio bars, beat, AUTO countdown,
// holds, fps, what is on, clip progress. Input 0 = the labels (text_mon). Same colours as the panel.
// Layout in pixels from the bottom left, 1030 x 360; monitor_labels.py places the words to match.

uniform vec4 uAudio;   // low, mid, high, kick (0-1)
uniform vec4 uPeak;    // slow-falling low, mid, high
uniform vec4 uBeat;    // beat count (float), bang every N beats, beat bang on, auto running
uniform vec4 uAuto;    // Auto on, last input time, next auto change time, idle seconds
uniform vec4 uAuto2;   // auto step seconds, now, fps, clip position 0-1
uniform vec4 uFx;      // METAL, EDGE, BLOB, CRASH on
uniform vec4 uIn;      // VIDEO, HUD, POP on, video source is clips
uniform vec4 uRaw;     // raw low, mid, high (before auto gain), auto gain on (MetalShow.81)
uniform vec4 uHold;    // STROBE, TILT, BLACK held, clip group index

out vec4 fragColor;

const vec3 BACK  = vec3(0.035, 0.085, 0.095);
const vec3 BACK2 = vec3(0.045, 0.125, 0.125);
const vec3 TRACK = vec3(0.105, 0.225, 0.245);
const vec3 BODY  = vec3(0.055, 0.125, 0.140);
const vec3 AQUA  = vec3(0.420, 0.880, 0.950);
const vec3 SEA   = vec3(0.210, 0.800, 0.640);
const vec3 LIME  = vec3(0.740, 1.000, 0.260);
const vec3 AMBER = vec3(1.000, 0.700, 0.150);
const vec3 RED   = vec3(1.000, 0.180, 0.150);

float inRect(vec2 p, vec4 r)    // r = x0, y0, x1, y1
{
	return step(r.x, p.x) * step(p.x, r.z) * step(r.y, p.y) * step(p.y, r.w);
}

// a lit / unlit tile like the panel buttons
vec3 tile(vec3 col, vec2 p, vec4 r, float lit, vec3 on)
{
	if (inRect(p, r) < 0.5) return col;
	bool edge = p.x < r.x + 1.0 || p.x > r.z - 1.0 || p.y < r.y + 1.0 || p.y > r.w - 1.0;
	if (lit > 0.5) return edge ? on : on * 0.55;
	return edge ? TRACK : BODY;
}

// vertical segmented meter with a peak segment
vec3 meter(vec3 col, vec2 p, vec4 r, float level, float peak, vec3 tone)
{
	if (inRect(p, r) < 0.5) return col;
	const float SEG = 10.0;
	float h = r.w - r.y;
	float k = floor((p.y - r.y) / SEG);
	if (fract((p.y - r.y) / SEG) > 0.75) return col;
	float y = (k + 0.5) * SEG / h;
	float pk = floor(clamp(peak, 0.0, 1.0) * h / SEG);
	if (k == pk && peak > 0.02) return LIME;
	if (y < level) return mix(tone, LIME, smoothstep(0.7, 1.0, y));
	return TRACK * 0.8;
}

// horizontal progress bar
vec3 bar(vec3 col, vec2 p, vec4 r, float v, vec3 tone)
{
	if (inRect(p, r) < 0.5) return col;
	float x = (p.x - r.x) / (r.z - r.x);
	return x < clamp(v, 0.0, 1.0) ? tone : TRACK * 0.8;
}

void main()
{
	vec2 res = uTDOutputInfo.res.zw;
	vec2 p = vUV.st * res;
	vec3 col = mix(BACK, BACK2, vUV.t * 0.7 + 0.15 * sin(vUV.s * 3.1));
	float now = uAuto2.y;

	// ---- AUDIO: LOW MID HIGH meters + KICK lamp ----
	// wide bar = what the effects get, thin bar right of it = raw level before auto gain
	col = meter(col, p, vec4(30, 50, 90, 310), uAudio.x, uPeak.x, SEA);
	col = meter(col, p, vec4(125, 50, 185, 310), uAudio.y, uPeak.y, AQUA);
	col = meter(col, p, vec4(220, 50, 280, 310), uAudio.z, uPeak.z, mix(SEA, LIME, 0.6));
	col = meter(col, p, vec4(95, 50, 110, 310), uRaw.x, 0.0, vec3(0.55, 0.62, 0.62));
	col = meter(col, p, vec4(190, 50, 205, 310), uRaw.y, 0.0, vec3(0.55, 0.62, 0.62));
	col = meter(col, p, vec4(285, 50, 300, 310), uRaw.z, 0.0, vec3(0.55, 0.62, 0.62));
	if (inRect(p, vec4(320, 50, 390, 310)) > 0.5)
		col = mix(BODY, LIME, clamp(uAudio.w, 0.0, 1.0));

	// ---- BEAT: one square per beat, the bang beat outlined ----
	float n = clamp(floor(uBeat.y + 0.5), 1.0, 8.0);
	float w = (270.0 - (n - 1.0) * 8.0) / n;
	float beat = floor(uBeat.x);
	float cur = mod(beat, n);
	float fade = 1.0 - fract(uBeat.x) * 0.7;
	for (float i = 0.0; i < 8.0; i++) {
		if (i >= n) break;
		vec4 r = vec4(430.0 + i * (w + 8.0), 255.0, 430.0 + i * (w + 8.0) + w, 300.0);
		if (inRect(p, r) > 0.5) {
			col = i == cur ? mix(BODY, (i == n - 1.0 ? LIME : AQUA), fade) : BODY;
			bool edge = p.x < r.x + 1.5 || p.x > r.z - 1.5 || p.y < r.y + 1.5 || p.y > r.w - 1.5;
			if (edge) col = (i == n - 1.0 && uBeat.z > 0.5 && uBeat.w > 0.5) ? LIME : TRACK;
		}
	}

	// ---- AUTO: waiting for idle (sea) or counting to the next change (lime) ----
	float waitp = clamp((now - uAuto.y) / max(uAuto.w, 0.1), 0.0, 1.0);
	float stepp = 1.0 - clamp((uAuto.z - now) / max(uAuto2.x, 0.1), 0.0, 1.0);
	vec4 ab = vec4(430, 165, 700, 192);
	if (uAuto.x < 0.5) col = bar(col, p, ab, 0.0, SEA);
	else if (uBeat.w < 0.5) col = bar(col, p, ab, waitp, SEA);
	else col = bar(col, p, ab, stepp, LIME);

	// ---- HOLDS: STROBE TILT BLACK (black = red warning) ----
	float tw = (270.0 - 16.0) / 3.0;
	col = tile(col, p, vec4(430, 95, 430 + tw, 130), uHold.x, AMBER);
	col = tile(col, p, vec4(438 + tw, 95, 438 + 2.0 * tw, 130), uHold.y, AMBER);
	col = tile(col, p, vec4(446 + 2.0 * tw, 95, 700, 130), uHold.z, RED);

	// ---- FPS: bar to 60, marks at 20 / 25 / 30 ----
	float fps = uAuto2.z;
	vec3 ft = fps < 20.0 ? RED : (fps < 25.0 ? AMBER : SEA);
	vec4 fr = vec4(430, 36, 700, 54);
	col = bar(col, p, fr, fps / 60.0, ft);
	for (int m = 0; m < 3; m++) {
		float mx = 430.0 + 270.0 * float(20 + 5 * m) / 60.0;
		if (abs(p.x - mx) < 0.8 && p.y > 30.0 && p.y < 60.0) col = AQUA;
	}

	// ---- NOW: effects on, inputs on, clip position ----
	float fw = (290.0 - 18.0) / 4.0;
	for (int k = 0; k < 4; k++) {
		float x0 = 730.0 + float(k) * (fw + 6.0);
		col = tile(col, p, vec4(x0, 270, x0 + fw, 300), uFx[k], SEA);
	}
	float iw = (290.0 - 12.0) / 3.0;
	for (int k = 0; k < 3; k++) {
		float x0 = 730.0 + float(k) * (iw + 6.0);
		col = tile(col, p, vec4(x0, 225, x0 + iw, 255), uIn[k], AQUA);
	}
	col = bar(col, p, vec4(730, 143, 1020, 155), uAuto2.w, uIn.w > 0.5 && uIn.x > 0.5 ? LIME : SEA * 0.6);

	// whole monitor edge goes red while BLACK is held
	if (uHold.z > 0.5 && (p.x < 4.0 || p.x > res.x - 4.0 || p.y < 4.0 || p.y > res.y - 4.0)) col = RED;

	vec4 words = texture(sTD2DInputs[0], vUV.st);
	col = col * (1.0 - words.a) + words.rgb;
	fragColor = TDOutputSwizzle(vec4(col, 1.0));
}
