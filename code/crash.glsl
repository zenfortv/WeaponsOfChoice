// /fx_strobe = CRASH: a PixelCrash-style cell mosaic (pixelcrash.xyz by @van_der_ex) that flashes.
// The frame is cut into square cells; each cell reads the video at its centre and, by brightness,
// falls into one of 3 layers like PixelCrash's defaults:
//   layer 1  above 200/255   solid light cell #E5E5E5 + symbol #AAAAAA
//   layer 2  below  55/255   symbol only #E6E6E6 (on the dark)
//   layer 3  80 - 120/255    cell with the sampled colour + symbol
// Symbols are 5x5 pixel glyphs packed as bits here (no font file). Densest glyph for the brightest cell.
uniform float uCell;     // cell size in pixels
uniform float uCrash;    // 0 video .. 1 full crash (the flash)
uniform float uSource;   // how much video shows under the empty cells
uniform float uInvert;   // Action2 flash: invert
uniform float uSeed;     // frame number, symbols flicker a little
out vec4 fragColor;

const int GLYPHS[12] = int[12](11512810, 14743086, 15252014, 18667121, 8682793, 16267326, 18157905, 14815374, 1118480, 32505856, 131200, 4194304);   // #@8N4SXI/_:.

float glyph(int g, vec2 f) {                // f = 0..1 inside the cell, y up
    vec2 p = f * 7.0 - 1.0;                 // 1 cell of padding around a 5x5 glyph
    if (p.x < 0.0 || p.y < 0.0 || p.x >= 5.0 || p.y >= 5.0) return 0.0;
    int col = int(p.x), row = 4 - int(p.y);
    return float((GLYPHS[g] >> (row * 5 + col)) & 1);
}

float hash(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }

void main() {
    vec2 res = uTDOutputInfo.res.zw;
    vec2 px = vUV.st * res;
    vec4 video = texture(sTD2DInputs[0], vUV.st);
    vec2 cell = floor(px / uCell);
    vec2 f = fract(px / uCell);
    vec3 s = texture(sTD2DInputs[0], (cell + 0.5) * uCell / res).rgb;
    float l = dot(s, vec3(0.299, 0.587, 0.114)) * 255.0;
    int n = 12;
    float jitter = hash(cell + floor(uSeed / 4.0)) * 1.5;
    vec3 base = video.rgb * uSource;
    vec3 c = base;
    if (l >= 200.0) {                                   // layer 1
        int g = clamp(int((255.0 - l) / 55.0 * 4.0 + jitter), 0, n - 1);
        c = mix(vec3(0.898), vec3(0.667), glyph(g, f));
    } else if (l <= 55.0) {                             // layer 2
        int g = clamp(int((55.0 - l) / 55.0 * float(n - 1) + jitter), 0, n - 1);
        c = mix(base, vec3(0.902), glyph(g, f));
    } else if (l >= 80.0 && l <= 120.0) {               // layer 3
        int g = clamp(int((l - 80.0) / 40.0 * 6.0 + jitter), 0, n - 1);
        c = mix(s * 1.25, vec3(0.05), glyph(g, f));
    }
    c = mix(c, 1.0 - c, uInvert);
    fragColor = TDOutputSwizzle(vec4(mix(video.rgb, c, clamp(uCrash, 0.0, 1.0)), 1.0));
}
