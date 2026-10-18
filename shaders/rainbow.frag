#include <flutter/runtime_effect.glsl>

uniform vec2 uSize;
uniform float uTime;
uniform vec4 uColor;

out vec4 fragColor;

vec3 rainbow(float t) {
    vec3 a = vec3(0.5, 0.5, 0.5);
    vec3 b = vec3(0.5, 0.5, 0.5);
    vec3 c = vec3(1.0, 1.0, 1.0);
    vec3 d = vec3(0.0, 0.33, 0.67);
    return a + b * cos(6.28318 * (c * t + d));
}

void main() {
    vec2 pos = FlutterFragCoord().xy;
    float hue = fract((pos.x + pos.y) * 0.005 + uTime * 0.5);
    vec3 col = rainbow(hue);
    fragColor = vec4(col * uColor.a, uColor.a);
}
