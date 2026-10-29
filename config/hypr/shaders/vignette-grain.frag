#version 300 es
// no time uniform, so hyprland doesn't have to keep redrawing

precision highp float;
in vec2 v_texcoord;
layout(location = 0) out vec4 fragColor;
uniform sampler2D tex;

float hash(vec2 p) {
    vec3 p3 = fract(vec3(p.xyx) * 0.1031);
    p3 += dot(p3, p3.yzx + 33.33);
    return fract((p3.x + p3.y) * p3.z);
}

void main() {
    vec4 c = texture(tex, v_texcoord);

    vec2 q = v_texcoord - 0.5;
    float vignette = 1.0 - 0.16 * smoothstep(0.35, 0.95, length(q * vec2(1.0, 0.9)) * 1.6);
    float grain = (hash(gl_FragCoord.xy) - 0.5) * 0.018;

    c.rgb = c.rgb * vignette + grain;
    fragColor = c;
}
