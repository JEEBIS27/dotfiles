// Approximate Rio's 60% cursor trail with a 100–400 ms decay.
void mainImage(out vec4 fragColor, in vec2 fragCoord) {
    fragColor = texture(iChannel0, fragCoord / iResolution.xy);
    vec2 size = max(iCurrentCursor.zw, vec2(1.0));
    vec2 current = iCurrentCursor.xy + vec2(size.x, -size.y) * 0.5;
    vec2 previous = iPreviousCursor.xy + vec2(iPreviousCursor.z, -iPreviousCursor.w) * 0.5;
    float age = max(0.0, iTime - iTimeCursorChange);
    if (iFocus <= 0 || age >= 0.4 || length((current - previous) / size) < 2.0) return;
    vec2 tail = mix(previous, current, smoothstep(0.0, 0.4, age));
    vec2 a = tail / size;
    vec2 b = current / size;
    vec2 point = fragCoord / size;
    vec2 segment = b - a;
    float t = clamp(dot(point - a, segment) / max(dot(segment, segment), 0.0001), 0.0, 1.0);
    float mask = 1.0 - smoothstep(0.3, 0.5, length(point - mix(a, b, t)));
    if (all(lessThan(abs(fragCoord - current), size * 0.5))) return;
    float alpha = 0.6 * (1.0 - smoothstep(0.1, 0.4, age)) * mask;
    fragColor.rgb = mix(fragColor.rgb, iCurrentCursorColor.rgb, alpha);
}
