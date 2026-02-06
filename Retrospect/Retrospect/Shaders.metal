#include <metal_stdlib>
using namespace metal;

struct VertexOut {
    float4 position [[position]];
    float2 uv;
};

vertex VertexOut meshGradientVertex(uint vertexID [[vertex_id]],
                                  constant float2* vertices [[buffer(0)]],
                                  constant float2* points [[buffer(1)]]) {
    VertexOut out;
    out.position = float4(vertices[vertexID], 0, 1);
    out.uv = (vertices[vertexID] + 1.0) * 0.5;  // Convert to UV space
    return out;
}

float2 hermite(float2 p0, float2 p1, float2 p2, float2 p3, float t) {
    float t2 = t * t;
    float t3 = t2 * t;
    
    float h00 = 2.0 * t3 - 3.0 * t2 + 1.0;
    float h10 = t3 - 2.0 * t2 + t;
    float h01 = -2.0 * t3 + 3.0 * t2;
    float h11 = t3 - t2;
    
    return h00 * p1 + h10 * (p2 - p0) + h01 * p2 + h11 * (p3 - p1);
}

float4 interpolateColors(float4 c0, float4 c1, float4 c2, float4 c3, float t) {
    float t2 = t * t;
    float t3 = t2 * t;
    
    float h00 = 2.0 * t3 - 3.0 * t2 + 1.0;
    float h10 = t3 - 2.0 * t2 + t;
    float h01 = -2.0 * t3 + 3.0 * t2;
    float h11 = t3 - t2;
    
    return h00 * c1 + h10 * (c2 - c0) + h01 * c2 + h11 * (c3 - c1);
}

fragment float4 meshGradientFragment(VertexOut in [[stage_in]],
                                   constant float2* points [[buffer(0)]],
                                   constant float4* colors [[buffer(1)]],
                                   constant uint& pointCount [[buffer(2)]]) {
    float2 uv = in.uv;
    float4 finalColor = float4(0);
    float totalWeight = 0;
    
    // For each control point
    for (uint i = 0; i < pointCount; i++) {
        // Calculate distance to control point
        float2 diff = uv - points[i];
        float dist = length(diff);
        
        // Weight is inverse of distance squared
        float weight = 1.0 / (1.0 + dist * dist * 8.0);
        
        // Accumulate weighted colors
        finalColor += colors[i] * weight;
        totalWeight += weight;
    }
    
    // Normalize colors by total weight
    if (totalWeight > 0) {
        finalColor /= totalWeight;
    }
    
    return finalColor;
} 