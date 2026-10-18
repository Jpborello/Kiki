#include <flutter/runtime_effect.glsl>

uniform vec2 uSize;
uniform float uTime;
uniform vec4 uColor;

out vec4 fragColor;

float hash(vec2 p) {
    return fract(sin(dot(p, vec2(12.9898, 78.233))) * 43758.5453);
}

void main() {
    vec2 st = FlutterFragCoord().xy / uSize;
    vec2 grid = floor(FlutterFragCoord().xy / 8.0);
    float n = hash(grid);
    float sparkle = pow(abs(sin(uTime * 6.0 + n * 6.2831)), 10.0);
    
    vec3 baseColor = uColor.rgb;
    vec3 glitterColor = mix(baseColor, vec3(1.0, 1.0, 0.8), sparkle);
    
    fragColor = vec4(glitterColor * uColor.a, uColor.a * (0.8 + 0.2 * sparkle));
}
