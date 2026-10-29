#version 440
// one sdf: the line, the pools and up to three sheets, merged with a circular smooth union.
// nothing reads time, it only redraws when a uniform changes.
// pixel space, y down, inside is negative.

layout(location = 0) in vec2 qt_TexCoord0;
layout(location = 0) out vec4 fragColor;

layout(std140, binding = 0) uniform buf {
    mat4 qt_Matrix;
    float qt_Opacity;
    vec2 size;
    float line;
    float poolBlend;
    float dropBlend;
    float dropRadius;
    vec4 pool0;
    vec4 pool1;
    vec4 pool2;
    vec4 drop0;
    vec4 drop1;
    vec4 drop2;
    vec4 bend0;
    vec4 bend1;
    vec4 bend2;
    vec4 ink;
    vec4 inkDeep;
    vec4 glow;
    vec2 cursor;
    float rimBase;
    float light;
    vec4 ripple;
    vec4 pulse0;
    vec4 pulse1;
    vec4 pulse2;
    vec4 pulse3;
};

float sdBox(vec2 p, vec2 c, vec2 h, float r) {
    vec2 d = abs(p - c) - h + vec2(r);
    return length(max(d, vec2(0.0))) + min(max(d.x, d.y), 0.0) - r;
}

// fillet is an exact arc of radius k
float smin(float a, float b, float k) {
    return max(k, min(a, b)) - length(max(vec2(k) - vec2(a, b), vec2(0.0)));
}

float pool(vec2 p, vec4 q) {
    if (q.y - q.x <= 0.5) return 1e5;
    const float top = -200.0;
    vec2 c = vec2(0.5 * (q.x + q.y), 0.5 * (top + q.z));
    vec2 h = vec2(0.5 * (q.y - q.x), 0.5 * (q.z - top));
    return sdBox(p, c, h, q.w);
}

// a moving sheet narrows and sags a bit. content is drawn separately and never deforms
float sheet(vec2 p, vec4 r, vec4 b) {
    if (r.z <= 0.5 || r.w <= 0.5) return 1e5;
    vec2 c = r.xy + 0.5 * r.zw;
    vec2 h = max(0.5 * r.zw - vec2(b.y, 0.0), vec2(1.0));
    float d = sdBox(p, c, h, min(dropRadius, min(h.x, h.y)));
    if (b.x > 0.01) {
        float u = clamp((p.x - c.x) / h.x, -1.0, 1.0);
        float prof = 1.0 - u * u;
        d -= b.x * prof * prof * smoothstep(c.y, r.y + r.w, p.y);
    }
    return d;
}

float hash(vec2 q) {
    q = fract(q * vec2(123.34, 456.21));
    q += dot(q, q + 45.32);
    return fract(q.x * q.y);
}

float pulse(vec2 p, vec4 q) {
    if (q.w <= 0.0 || q.z >= 1.0) return 0.0;
    float age = q.z;
    float r = mix(6.0, 300.0, 1.0 - (1.0 - age) * (1.0 - age));
    float dist = length(p - q.xy);
    float wdt = 9.0 + 34.0 * age;
    float band = exp(-((dist - r) * (dist - r)) / (wdt * wdt));
    float flash = exp(-(dist * dist) / (34.0 * 34.0)) * (1.0 - age) * (1.0 - age);
    float fade = (1.0 - age) * (1.0 - age);
    return q.w * (band * fade + flash);
}

void main() {
    vec2 p = qt_TexCoord0 * size;

    float d = p.y - line;
    d = smin(d, pool(p, pool0), poolBlend);
    d = smin(d, pool(p, pool1), poolBlend);
    d = smin(d, pool(p, pool2), poolBlend);
    d = smin(d, sheet(p, drop0, bend0), dropBlend);
    d = smin(d, sheet(p, drop1, bend1), dropBlend);
    d = smin(d, sheet(p, drop2, bend2), dropBlend);

    float a = clamp(0.5 - d, 0.0, 1.0);

    vec2 dc = p - cursor;
    float near = cursor.x < 0.0 ? 0.0 : exp(-dot(dc, dc) / (300.0 * 300.0));
    float energy = rimBase + (1.0 - rimBase) * near;

    if (ripple.z > 0.0) {
        float travel = ripple.y * 520.0;
        float w = 46.0 + 60.0 * ripple.y;
        float l = p.x - (ripple.x - travel);
        float r = p.x - (ripple.x + travel);
        float pr = exp(-(l * l) / (w * w)) + exp(-(r * r) / (w * w));
        energy += ripple.z * (1.0 - ripple.y) * pr;
    }

    float touch = pulse(p, pulse0) + pulse(p, pulse1) + pulse(p, pulse2) + pulse(p, pulse3);
    energy += touch * 1.4;

    float depth = smoothstep(0.0, 90.0, -d);
    vec3 inkc = mix(ink.rgb, inkDeep.rgb, depth);
    inkc += glow.rgb * 0.045 * light * exp(min(d, 0.0) / 14.0);

    if (touch > 0.002) {
        vec2 cell = floor(p / 7.0);
        vec2 at = cell * 7.0 + 1.0 + 5.0 * vec2(hash(cell), hash(cell + 3.1));
        float r = length(p - at);
        float speck = exp(-r * r / 1.1) * step(0.6, hash(cell + 11.0)) * (0.5 + 0.5 * hash(cell + 5.7));
        inkc += glow.rgb * light * min(touch, 1.2) * (0.05 + 0.85 * speck);
    }

    float sh = d > 0.0 ? 0.72 * pow(1.0 - smoothstep(0.0, 40.0, d), 1.6) : 0.0;

    vec4 col = vec4(0.0, 0.0, 0.0, sh);
    col = vec4(inkc * a * ink.a, a * ink.a) + col * (1.0 - a * ink.a);

    float rim = 1.0 - smoothstep(0.0, 1.25, abs(d + 0.35));
    float bloom = d > 0.0 ? exp(-d / 7.0) * 0.55 : 0.0;
    col.rgb += glow.rgb * light * (rim * (0.30 + 0.70 * min(energy, 1.8)) + bloom * energy * 0.6);

    fragColor = col * qt_Opacity;
}
