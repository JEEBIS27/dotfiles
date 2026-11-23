#version 440
layout(location = 0) in vec2 qt_TexCoord0;
layout(location = 0) out vec4 fragColor;
layout(std140, binding = 0) uniform buf {
    mat4 qt_Matrix;
    float qt_Opacity;
    vec2 canvasSize;
    vec4 body;
    vec4 satellite;
    vec4 fillTint;
    vec4 edgeTint;
    float stroke;
    float tension;
    float bodyRadius;
};

float capsule(vec2 p, vec4 box, float radius) {
    float r = min(radius, min(box.z, box.w) * 0.5);
    vec2 q = abs(p - box.xy) - (box.zw * 0.5 - r);
    return length(max(q, 0.0)) + min(max(q.x, q.y), 0.0) - r;
}

void main() {
    vec2 p = qt_TexCoord0 * canvasSize;
    float a = capsule(p, body, bodyRadius);
    float b = capsule(p, satellite, satellite.w);
    // Smooth union stretches the facing surfaces and keeps one continuous keyline.
    float h = max(tension - abs(a - b), 0.0) / tension;
    float d = min(a, b) - h * h * tension * 0.25;
    float aa = max(0.01, fwidth(d) * 0.5);
    float fill = 1.0 - smoothstep(-aa, aa, d);
    float outer = 1.0 - smoothstep(stroke - aa, stroke + aa, d);
    fragColor = qt_Opacity * (fill * fillTint + (outer - fill) * edgeTint);
}
