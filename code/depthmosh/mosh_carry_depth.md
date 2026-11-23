# Make the mosh carry depth (small change to code/mosh.glsl, not applied yet)

Idea: today the mosh moves only colour and writes alpha = 1. If the depth rides in alpha, every smeared
pixel keeps the depth it had when it was smeared. The smears then become solid shapes that the
volume pass can light and extrude, not flat paint.

Input 1 (source) must have depth in alpha: put a Reorder TOP (or Math/Composite) before glsl_mosh that
takes RGB from /input/out1 and A from depth_proxy (or the Depth Anything TOP).

Changes in mosh.glsl `main()` (5 lines):

```glsl
// 1. read alpha too
vec4 lastA  = texelFetch(sTD2DInputs[0], ivec2(gl_FragCoord.xy), 0);
vec4 srcA   = texture(sTD2DInputs[1], uv);
vec4 predA  = texture(sTD2DInputs[0], clamp(uv + field.xy * mix(1.0, 0.4 + 1.2 * predA_depth_guess, uParallax), 0.0, 1.0));
```

Simpler, safe version (what to actually paste):

```glsl
uniform float uParallax;   // 0 = all depths move the same, 1 = near moves 3x more than far

// after `field` is known:
float dHere = texture(sTD2DInputs[0], uv).a;                 // depth carried in the mosh
vec2  move  = field.xy * mix(1.0, 0.3 + 1.4 * dHere, uParallax);
vec4  pred  = texture(sTD2DInputs[0], clamp(uv + move, 0.0, 1.0));
vec3 predicted = pred.rgb;
float depth    = pred.a;

// where the picture is refreshed or leaks, depth follows the source too:
//   picture = mix(picture, source, uLeak);  ->  depth = mix(depth, srcDepth, uLeak);
//   picture = source (refresh)              ->  depth = srcDepth;
//   still                                    ->  depth = last.a;

fragColor = TDOutputSwizzle(vec4(clamp(picture, 0.0, 1.0), clamp(depth, 0.0, 1.0)));
```

The feedback TOP and the GLSL TOP must be RGBA (16-bit float is best, 8-bit makes depth steps visible).
uParallax is the "layers" feeling: near pixels smear further than far ones, like a camera moving.
