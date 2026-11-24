#version 440
layout(location = 0) in vec2 qt_TexCoord0;
layout(location = 0) out vec4 fragColor;
layout(std140, binding = 0) uniform buf {
    mat4 qt_Matrix;
    float qt_Opacity;
    vec2 pixel;
    float tint;
    float rim;
    float light;
    vec4 outside;
};
layout(binding = 1) uniform sampler2D source;

float at(vec2 p) {
    if (p.x < 0.0) return outside.x;
    if (p.y < 0.0) return outside.y;
    if (p.x > 1.0) return outside.z;
    if (p.y > 1.0) return outside.w;
    return step(0.003, texture(source, p).a);
}

void main() {
    vec2 uv = qt_TexCoord0;
    vec4 c = texture(source, uv);
    if (c.a < 0.003) {
        fragColor = vec4(0.0);
        return;
    }
    vec3 base = c.rgb / c.a;
    float cover = clamp(c.a / max(tint, 0.01), 0.0, 1.0);

    if (cover > 0.999) {
        float inner = 0.0;
        for (int k = 0; k < 8; k++) {
            float u = float(k) * 0.78539816;
            inner += at(uv + vec2(cos(u), sin(u)) * pixel * rim);
        }
        if (inner > 7.5) {
            fragColor = vec4(base * tint, tint) * qt_Opacity;
            return;
        }
    }

    vec2 grad = vec2(0.0);
    float far = 0.0;
    float near = 0.0;
    for (int i = 0; i < 16; i++) {
        float t = float(i) * 0.39269908;
        vec2 d = vec2(cos(t), sin(t));
        float a1 = at(uv + d * pixel * rim);
        float a2 = at(uv + d * pixel * rim * 0.45);
        float a3 = at(uv + d * pixel * 1.6);
        far += a1 + a2;
        near += a3;
        grad += d * (a1 + 0.6 * a2 + 0.6 * a3);
    }
    far /= 32.0;
    near /= 16.0;

    float edge = clamp((1.0 - far) * 2.0, 0.0, 1.0);
    float fres = edge * edge;
    float line = clamp((1.0 - near) * 2.6, 0.0, 1.0);

    vec2 n = length(grad) > 0.001 ? -normalize(grad) : vec2(0.0);
    vec2 L = normalize(vec2(-1.0, -1.25));
    float facing = dot(n, L);
    float spec = pow(max(facing, 0.0), 2.0);
    float back = pow(max(-facing, 0.0), 2.0);
    vec2 tang = vec2(-n.y, n.x);

    vec3 col = base;
    col = mix(col, col * 1.12 + 0.03, fres * 0.6);
    col += vec3(0.05, 0.0, -0.04) * fres * dot(tang, L);

    float a = tint * cover;
    vec4 outc = vec4(col * a, a);

    vec3 shine = clamp(base * 1.9 + 0.14, 0.0, 1.0);
    float glow = fres * (0.04 + 0.09 * spec + 0.03 * back) * light;
    float rimA = line * (0.07 + 0.20 * spec + 0.07 * back) * light;
    float hl = clamp(glow + rimA, 0.0, 1.0) * cover;
    outc = outc * (1.0 - hl) + vec4(shine * hl, hl);

    fragColor = outc * qt_Opacity;
}
