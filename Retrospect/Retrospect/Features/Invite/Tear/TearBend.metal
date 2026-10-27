//
//  TearBend.metal
//  TEAR.motion: the stub as one sheet of paper that peels. Right of the tear front it is still
//  joined and flat; left of it the flap curves continuously (TearCurve.swift is the same curve,
//  and the spec): the tangent turns as angle * (1 - (1 - s/length)^exponent), tightest at the peel,
//  easing out to the tip, and every point keeps its distance from the perforation along the paper's
//  normal (no stretch, no seam, no second copy). A distortion effect returns, for each drawn pixel,
//  where on the flat stub it came from: the curve's inverse, solved by a few Newton-like steps.
//
#include <metal_stdlib>
using namespace metal;

namespace tear {

// How far the tangent has turned down (radians) s points left of the front.
inline float turnAt(float s, float down, float length, float exponent) {
    if (s <= 0.0 || length <= 0.0) { return 0.0; }
    float share = min(s / length, 1.0);
    return down * (1.0 - pow(1.0 - share, exponent));
}

// Where the perforation line, s points left of the front, now is (relative to the front).
// Four-point Gauss-Legendre, the same as TearCurve.edge(at:).
inline float2 edgeAt(float s, float down, float length, float exponent) {
    if (s <= 0.0) { return float2(-s, 0.0); }
    const float nodes[4] = { -0.8611363116, -0.3399810436, 0.3399810436, 0.8611363116 };
    const float weights[4] = { 0.3478548451, 0.6521451549, 0.6521451549, 0.3478548451 };
    float bent = min(s, length);
    float2 sum = float2(0.0);
    for (int i = 0; i < 4; i++) {
        float sigma = bent * 0.5 * (nodes[i] + 1.0);
        float turn = turnAt(sigma, down, length, exponent);
        sum += weights[i] * float2(-cos(turn), sin(turn));
    }
    sum *= bent * 0.5;
    float tip = turnAt(length, down, length, exponent);
    float rest = s - bent;
    return sum + rest * float2(-cos(tip), sin(tip));
}

} // namespace tear

// front: the joined point's x; pivotY: the perforation; angle: the tip's tangent in radians
// (negative hangs the left end down, as rotationEffect); length: the flap's length; exponent: the curve.
[[ stitchable ]] float2 tearBend(float2 position, float front, float pivotY, float angle, float length, float exponent) {
    float down = -angle;
    float2 d = position - float2(front, pivotY);
    // first guess: the flat sheet; then correct along the paper's tangent and normal
    float s = -d.x;
    float h = d.y;
    for (int i = 0; i < 6; i++) {
        float turn = tear::turnAt(s, down, length, exponent);
        float2 tangent = float2(-cos(turn), sin(turn));
        float2 normal = float2(sin(turn), cos(turn));
        float2 placed = tear::edgeAt(s, down, length, exponent) + h * normal;
        float2 miss = d - placed;
        s += dot(miss, tangent);
        h += dot(miss, normal);
    }
    return float2(front - s, pivotY + h);
}
