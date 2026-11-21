// OSC 4 carries rectangles in top-left terminal-cell coordinates.
ivec2 focusPair(int slot) {
    int word = 0;
    for (int i = 0; i < 4; ++i) {
        ivec3 low = ivec3(round(iPalette[160 + 4 * slot + i].rgb * 255.0)) & ivec3(3);
        word = (word << 6) | (low.r << 4) | (low.g << 2) | low.b;
    }
    return ivec2(word >> 12, word & 4095);
}
bool insideFocusRect(ivec2 p, int slot) {
    return all(greaterThanEqual(p, focusPair(slot))) && all(lessThan(p, focusPair(slot + 1)));
}
// Ghostty's OpenGL postprocessing texture uses linear RGB. The requested
// factor applies to displayed sRGB bytes, including syntax and backgrounds.
vec3 dimDisplayRGB(vec3 linear) {
    vec3 srgb = mix(1.055 * pow(max(linear, vec3(0.0)), vec3(1.0 / 2.4)) - 0.055,
                    12.92 * linear, lessThanEqual(linear, vec3(0.0031308)));
    srgb *= 0.9;
    return mix(pow((srgb + 0.055) / 1.055, vec3(2.4)), srgb / 12.92,
               lessThanEqual(srgb, vec3(0.04045)));
}
void mainImage(out vec4 color, in vec2 pos) {
    color = texture(iChannel0, pos / iResolution.xy);
    if (any(notEqual(focusPair(0), ivec2(0x464, 0xf43)))) return;
    vec2 grid = vec2(focusPair(1));
    vec2 cell = vec2(focusPair(2));
    if (any(lessThan(cell, vec2(1.0)))) return;
    vec2 origin = floor((iResolution.xy - grid * cell) * 0.5);
    ivec2 p = ivec2(floor((vec2(pos.x, iResolution.y - pos.y) - origin) / cell));
    if ((insideFocusRect(p, 3) && !insideFocusRect(p, 5)) ||
        (insideFocusRect(p, 7) && !insideFocusRect(p, 9))) color.rgb = dimDisplayRGB(color.rgb);
}
