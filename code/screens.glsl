// Per-screen mask for an effect. The frame is split into 3 screens side by side at the SAME
// boundaries the crops use (crop_screen1-3 tile the frame: 0..uB.x | uB.x..uB.y | uB.y..1).
// uOn = faded on-amount per screen (null_mix s1 s2 s3 = On * Screen1/2/3, lagged by Fade).
// mask_screens: vec1 uB = (/crop_screen2 cropleft, cropright).
uniform vec3 uOn;
uniform vec2 uB;
out vec4 fragColor;

void main() {
    float x = vUV.s;
    float v = x < uB.x ? uOn.x : (x < uB.y ? uOn.y : uOn.z);
    fragColor = TDOutputSwizzle(vec4(v, v, v, 1.0));
}
