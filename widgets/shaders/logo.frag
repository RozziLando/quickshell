#version 440
layout(location = 0) in vec2 qt_TexCoord0;
layout(location = 0) out vec4 fragColor;
layout(std140, binding = 0) uniform buf {
    mat4 qt_Matrix;
    float qt_Opacity;
    vec4 tint;
};
layout(binding = 1) uniform sampler2D source;

void main() {
    vec4 c = texture(source, qt_TexCoord0);
    vec3 rgb = c.a > 0.001 ? c.rgb / c.a : vec3(0.0);
    float mx = max(rgb.r, max(rgb.g, rgb.b));
    float mn = min(rgb.r, min(rgb.g, rgb.b));
    float light = clamp((mx - 0.72) / 0.2, 0.0, 1.0);
    float sat = mx > 0.0 ? (mx - mn) / mx : 0.0;
    float plain = 1.0 - clamp((sat - 0.12) / 0.2, 0.0, 1.0);
    float a = c.a * (1.0 - light * plain) * tint.a * qt_Opacity;
    fragColor = vec4(tint.rgb * a, a);
}
