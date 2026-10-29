#version 440
// cover crop happens here, which is free; a ShaderEffectSource per image would cost a
// fullscreen buffer each

layout(location = 0) in vec2 qt_TexCoord0;
layout(location = 0) out vec4 fragColor;

layout(std140, binding = 0) uniform buf {
    mat4 qt_Matrix;
    float qt_Opacity;
    vec2 size;          // item size in px
    float progress;     // 0 = all old, 1 = all new
    float fromAspect;   // width / height of the old image's texture (0: no image)
    float toAspect;     // same for the new one
    vec4 glow;          // the accent
    vec4 base;          // shown where an image is missing
};

layout(binding = 1) uniform sampler2D fromTex;
layout(binding = 2) uniform sampler2D toTex;

vec2 cover(vec2 uv, float imgAspect) {
    float scr = size.x / size.y;
    if (imgAspect > scr)
        uv.x = 0.5 + (uv.x - 0.5) * scr / imgAspect;
    else
        uv.y = 0.5 + (uv.y - 0.5) * imgAspect / scr;
    return uv;
}

float hash(vec2 p) {
    return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

float noise(vec2 p) {
    vec2 i = floor(p), f = fract(p);
    vec2 u = f * f * (3.0 - 2.0 * f);
    return mix(mix(hash(i), hash(i + vec2(1, 0)), u.x),
               mix(hash(i + vec2(0, 1)), hash(i + vec2(1, 1)), u.x), u.y);
}

vec4 sampleOr(sampler2D t, vec2 uv, float aspect) {
    return aspect > 0.0 ? texture(t, cover(uv, aspect)) : base;
}

void main() {
    vec2 uv = qt_TexCoord0;
    vec2 px = uv * size;

    float band = 140.0;
    float swell = sin(px.x * 0.0061 + progress * 5.0) * 26.0
                + sin(px.x * 0.0153 - progress * 3.0) * 11.0
                + (noise(vec2(px.x * 0.02, progress * 6.0)) - 0.5) * 18.0;
    float front = mix(-band, size.y + band, progress) + swell;
    float dist = px.y - front;                    // < 0: already covered by the new image

    float ahead = clamp(1.0 - dist / band, 0.0, 1.0) * step(0.0, dist);
    vec2 bend = vec2(sin(px.y * 0.05 + progress * 20.0) * 0.004, -0.010) * ahead * ahead;
    vec4 oldC = sampleOr(fromTex, uv + bend, fromAspect);

    vec2 settle = 0.5 + (uv - 0.5) * mix(0.965, 1.0, smoothstep(0.0, 1.0, progress));
    vec4 newC = sampleOr(toTex, settle, toAspect);

    float cover_ = 1.0 - smoothstep(-2.0, 2.0, dist);
    vec4 col = mix(oldC, newC, cover_);

    float edge = exp(-abs(dist) / 9.0) + 0.35 * exp(-abs(dist) / 40.0);
    float strength = sin(clamp(progress, 0.0, 1.0) * 3.14159);
    col.rgb += glow.rgb * edge * 0.55 * strength;

    fragColor = vec4(col.rgb, 1.0) * qt_Opacity;
}
