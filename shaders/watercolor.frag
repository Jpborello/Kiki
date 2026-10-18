#include <flutter/runtime_effect.glsl>

uniform vec2 uSize;
uniform float uTime;
uniform vec4 uColor;

out vec4 fragColor;

float rand(vec2 co){
    return fract(sin(dot(co, vec2(12.9898, 78.233))) * 43758.5453);
}

void main() {
    vec2 st = FlutterFragCoord().xy / uSize;
    float noise = rand(floor(FlutterFragCoord().xy * 0.1));
    float edgeBleed = 0.8 + 0.4 * noise;
    vec3 watercolor = uColor.rgb * edgeBleed;
    fragColor = vec4(watercolor * uColor.a, uColor.a * 0.85);
}
