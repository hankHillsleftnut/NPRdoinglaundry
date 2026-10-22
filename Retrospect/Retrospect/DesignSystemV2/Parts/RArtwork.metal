//
//  RArtwork.metal
//  M14 S14 + S06: the artwork mesh and its grain, in one pass (principles/gradients.md).
//  Every point pulls the colour toward itself with a soft falloff, and the mix happens in
//  OKLab, so neighbouring colours blend without going grey or muddy. Grain is drawn per
//  device pixel in soft light, mono or multi (a separate grain per channel).
//

#include <metal_stdlib>
#include <SwiftUI/SwiftUI_Metal.h>
using namespace metal;

namespace rartwork {

float3 toLinear(float3 c) {
    return select(c / 12.92, pow((c + 0.055) / 1.055, 2.4), c > 0.04045);
}

float3 toSRGB(float3 c) {
    c = clamp(c, 0.0, 1.0);
    return select(c * 12.92, 1.055 * pow(c, 1.0 / 2.4) - 0.055, c > 0.0031308);
}

float3 oklabToLinear(float3 lab) {
    float l = lab.x + 0.3963377774 * lab.y + 0.2158037573 * lab.z;
    float m = lab.x - 0.1055613458 * lab.y - 0.0638541728 * lab.z;
    float s = lab.x - 0.0894841775 * lab.y - 1.2914855480 * lab.z;
    l = l * l * l;
    m = m * m * m;
    s = s * s * s;
    return float3(
        4.0767416621 * l - 3.3077115913 * m + 0.2309699292 * s,
        -1.2684380046 * l + 2.6097574011 * m - 0.3413193965 * s,
        -0.0041960863 * l - 0.7034186147 * m + 1.7076147010 * s);
}

float hash(float2 p, float seed) {
    float3 q = fract(float3(p.xyx) * float3(0.1031, 0.1030, 0.0973) + seed);
    q += dot(q, q.yzx + 33.33);
    return fract((q.x + q.y) * q.z);
}

float softLight(float base, float blend) {
    return blend <= 0.5
        ? base - (1.0 - 2.0 * blend) * base * (1.0 - base)
        : base + (2.0 * blend - 1.0) * ((base <= 0.25 ? ((16.0 * base - 12.0) * base + 4.0) * base : sqrt(base)) - base);
}

} // namespace rartwork

/// points: 7 floats each — x, y (share of the size), radius (share of the longer side),
/// weight (0–1), then the colour in OKLab. base: the colour where no point reaches, in OKLab.
/// softness 0–1 widens every falloff. grain: opacity, mode (0 mono, 1 multi), cell size in points.
[[ stitchable ]] half4 rArtworkMesh(
    float2 position, half4 current, float2 size,
    device const float *points, int count,
    float3 base, float softness,
    float grainOpacity, float grainMode, float grainCell)
{
    float longest = max(size.x, size.y);
    float2 uv = position / longest;
    float falloff = mix(5.0, 1.5, clamp(softness, 0.0, 1.0));

    // Points blend with each other by weight; together they cover the base like layered
    // alpha (1 − Π(1 − w)), so the base still shows wherever the points fade out.
    float3 lab = float3(0.0);
    float total = 0.0;
    float uncovered = 1.0;
    for (int i = 0; i + 6 < count; i += 7) {
        float2 centre = float2(points[i], points[i + 1]) * size / longest;
        float d = distance(uv, centre) / max(points[i + 2], 0.001);
        float w = points[i + 3] * exp(-d * d * falloff);
        lab += float3(points[i + 4], points[i + 5], points[i + 6]) * w;
        total += w;
        uncovered *= 1.0 - w;
    }
    float3 mixed = total > 0.0001 ? lab / total : base;
    lab = mix(base, mixed, 1.0 - uncovered);
    float3 rgb = rartwork::toSRGB(rartwork::oklabToLinear(lab));

    // Grain per device pixel; also dithers away 8-bit banding.
    float2 cell = floor(position / max(grainCell, 0.0001));
    float3 noise = grainMode < 0.5
        ? float3(rartwork::hash(cell, 0.0))
        : float3(rartwork::hash(cell, 0.0), rartwork::hash(cell, 1.7), rartwork::hash(cell, 3.1));
    float3 lit = float3(rartwork::softLight(rgb.r, noise.r), rartwork::softLight(rgb.g, noise.g), rartwork::softLight(rgb.b, noise.b));
    rgb = mix(rgb, lit, grainOpacity);

    return half4(half3(rgb), 1.0) * current.a;
}
