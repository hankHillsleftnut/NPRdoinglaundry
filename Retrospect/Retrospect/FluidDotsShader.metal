//
//  FluidDotsShader.metal
//  Retrospect
//
//  "Fluid Dots" metaball orb (siriFluidDotsCore).
//  Ported from a WebGL/GLSL reference fragment shader to Metal Shading Language.
//  The algorithm: N signed-distance dots arranged in a ring, fused with a smooth
//  minimum (metaballs), with spring-settle motion, a periodic gather/burst cycle,
//  soft glow, hue drift, and subtle chromatic aberration.
//

#include <metal_stdlib>
using namespace metal;

// ---- Constants (1:1 with the reference shader) ----
constant float TAU          = 6.28318530718;
constant int   N            = 6;
constant float SMOOTH_K     = 0.08;
constant float INTENSITY    = 0.0025;
constant float FALLOFF_P    = 1.35;
constant float FADE_START   = 0.02;
constant float FADE_END     = 0.56;
constant float ABERR        = 0.005;
constant float3 SPECTRAL    = float3(0.0, 0.0025, 0.005); // vec3(0.0,0.5,1.0) * ABERR
constant float HUE_SPEED    = 0.06;
constant float COLOR_K      = 0.5;
constant float SAT          = 0.01;
constant float HUE_SPAN     = 0.667;
constant float MERGE_PERIOD = 6.0;
constant float STAGGER      = 0.33;
constant float HOLD         = 0.0;
constant float W            = 4.6;
constant float L            = 3.2;
constant float PIERCE       = 0.12;
constant float RECOIL       = 0.035;
constant float REC_LAG      = 0.11;
constant float GATHER_PERIOD = 12.0;
constant float GATHER_START  = 9.2;
constant float GATHER_HOLD   = 0.8;
constant float GATHER_R      = 0.008;
constant float GATHER_DIM    = 0.85;
constant float GATHER_IN     = 1.8;
constant float GATHER_IN_L   = 7.5;
constant float BURST_W       = 6.5;
constant float BURST_L       = 4.0;
constant float CHARGE_T      = 0.30;
constant float CHARGE_SHRK   = 0.18;
constant float CHARGE_GLOW   = 0.35;
constant float FLASH_GAIN    = 1.2;
constant float FLASH_DECAY   = 7.0;

// GLSL-style mod (Metal's fmod truncates toward zero; GLSL mod floors).
inline float glslMod(float x, float y) { return x - y * floor(x / y); }

float hash11(float n) { return fract(sin(n * 127.1 + 311.7) * 43758.5453); }

float settleWL(float tau, float w, float l) {
    if (tau <= 0.0) return 0.0;
    return 1.0 - exp(-l * tau) * cos(w * tau);
}
float settle(float tau) { return settleWL(tau, W, L); }
float settleCrit(float tau, float l) {
    if (tau <= 0.0) return 0.0;
    return 1.0 - exp(-l * tau) * (1.0 + l * tau);
}

float smin(float a, float b, float k) {
    float h = max(k - abs(a - b), 0.0) / k;
    return min(a, b) - h * h * k * 0.25;
}

float3 hue2rgb(float h) {
    h = fract(h);
    float r = clamp(abs(h * 6.0 - 3.0) - 1.0, 0.0, 1.0);
    float g = clamp(2.0 - abs(h * 6.0 - 2.0), 0.0, 1.0);
    float b = clamp(2.0 - abs(h * 6.0 - 4.0), 0.0, 1.0);
    return float3(r, g, b);
}

float dotR(float fi, float seed, float t) {
    return 0.036 + 0.010 * sin(t * 1.3 + seed * TAU) + 0.005 * sin(t * 2.4 + fi * 1.3);
}

float dotSD(float2 p, float2 pos, float r, float t, float fi, float shapeDamp) {
    float2 d = p - pos;
    float sq = 0.075 * (0.5 + 0.5 * sin(t * 0.9 + fi * 2.0)) * shapeDamp;
    float ca = cos(t * 0.35 + fi), sa = sin(t * 0.35 + fi);
    d = float2x2(float2(ca, -sa), float2(sa, ca)) * d;
    d *= float2(1.0 + sq, 1.0 - sq);
    return length(d) - r;
}

float3 scene(float2 p, float t) {
    float k  = floor(t / MERGE_PERIOD);
    float u  = fract(t / MERGE_PERIOD);
    float te = u * MERGE_PERIOD;
    float tg = glslMod(t, GATHER_PERIOD);
    float g  = settleCrit((tg - GATHER_START) * GATHER_IN, GATHER_IN_L)
             - settleWL(tg - GATHER_START - GATHER_HOLD, BURST_W, BURST_L);
    float gC = clamp(g, 0.0, 1.0);
    float tb     = tg - (GATHER_START + GATHER_HOLD);
    float charge = smoothstep(-CHARGE_T, 0.0, min(tb, 0.0)) * gC;
    float flash  = tb > 0.0 ? exp(-tb * FLASH_DECAY) : 0.0;
    float gBright = mix(1.0, GATHER_DIM, gC) * (1.0 + CHARGE_GLOW * charge + FLASH_GAIN * flash);
    float3 total3 = float3(1e5);
    float3 cAcc   = float3(0.0);
    float  wAcc   = 1e-6;
    for (int i = 0; i < N; i++) {
        float fi   = float(i);
        float seed = hash11(fi);
        float ang  = fi / float(N) * TAU + t * 0.35;
        float2 dir = float2(cos(ang), sin(ang));
        float R    = 0.17 + 0.010 * sin(t * 1.0) + 0.007 * sin(t * 1.3 + seed * TAU);
        float pairId   = glslMod(fi, 3.0);
        float moverLow = glslMod(k + pairId, 2.0);
        float isMover  = (fi < 2.5) ? step(moverLow, 0.5) : step(0.5, moverLow);
        float goStart  = pairId * STAGGER;
        float retStart = 3.0 * STAGGER + HOLD + pairId * STAGGER;
        float m   = (settle(te - goStart)           - settle(te - retStart))           * isMover;
        float rec = (settle(te - goStart - REC_LAG) - settle(te - retStart - REC_LAG)) * (1.0 - isMover);
        float rSelf = dotR(fi, seed, t);
        rSelf = mix(rSelf, 0.036, gC);
        rSelf *= 1.0 - CHARGE_SHRK * charge;
        float fj    = glslMod(fi + 3.0, 6.0);
        float rPart = dotR(fj, hash11(fj), t);
        float deep   = -(R + RECOIL) - PIERCE * rPart;
        float radial = mix(R, deep, m) + RECOIL * rec;
        radial = mix(radial, GATHER_R, g);
        float2 pos = radial * dir;
        float sdR = dotSD(p - SPECTRAL.r * dir, pos, rSelf, t, fi, 1.0 - gC);
        float sdG = dotSD(p - SPECTRAL.g * dir, pos, rSelf, t, fi, 1.0 - gC);
        float sdB = dotSD(p - SPECTRAL.b * dir, pos, rSelf, t, fi, 1.0 - gC);
        total3 = float3(smin(total3.r, sdR, SMOOTH_K),
                        smin(total3.g, sdG, SMOOTH_K),
                        smin(total3.b, sdB, SMOOTH_K));
        float hue = fract(fi / float(N) + t * HUE_SPEED) * HUE_SPAN;
        float3 dotCol = mix(float3(1.0), hue2rgb(hue), SAT);
        float w = exp(-sdG * COLOR_K);
        cAcc += w * dotCol;
        wAcc += w;
    }
    float3 sd3   = max(total3, float3(0.0)) + 1e-4;
    float3 core3 = clamp(INTENSITY / pow(sd3, float3(FALLOFF_P)), 0.0, 1.0);
    float3 edge3 = float3(1.0) - smoothstep(float3(FADE_START), float3(FADE_END), sd3);
    float3 bright = core3 * edge3 * gBright;
    return bright * (cAcc / wAcc);
}

// ---- Uniforms ----
struct FluidUniforms {
    float2 iResolution;
    float  iTime;
};

struct FluidVSOut {
    float4 position [[position]];
};

// Full-screen triangle from vertex id (no vertex buffer needed).
vertex FluidVSOut fluidDotsVertex(uint vid [[vertex_id]]) {
    float2 verts[3] = { float2(-1.0, -1.0), float2(3.0, -1.0), float2(-1.0, 3.0) };
    FluidVSOut out;
    out.position = float4(verts[vid], 0.0, 1.0);
    return out;
}

fragment float4 fluidDotsFragment(FluidVSOut in [[stage_in]],
                                  constant FluidUniforms& u [[buffer(0)]]) {
    // Metal's [[position]] has a top-left origin; flip Y to match GLSL gl_FragCoord.
    float2 fragCoord = float2(in.position.x, u.iResolution.y - in.position.y);
    float2 res = u.iResolution;
    float2 p = (2.0 * fragCoord - res) / min(res.x, res.y);
    float t = u.iTime;
    p /= 1.0 + 0.03 * sin(t * 1.0);
    float3 col = scene(p, t);
    col *= 1.0 + 0.05 * sin(t * 1.0 + 1.0);
    col = pow(col, float3(1.0 / 1.2));
    col = min(col, 1.0);
    float n = fract(sin(dot(fragCoord, float2(12.9898, 78.233))) * 43758.5453);
    col += (n - 0.5) / 255.0;
    return float4(col, 1.0);
}

// ============================================================================
// VARIATIONS
// Same "aura" recipe as the original (soft glow on a signed-distance field +
// chromatic aberration + low-sat hue drift + gamma/dither). Only the geometry
// and motion underneath change, so each reads distinct but keeps the feeling.
// ============================================================================

float2 normalizeSafe(float2 v) {
    float l = length(v);
    return l > 1e-4 ? v / l : float2(1.0, 0.0);
}

// Shared compositor: turn a per-channel signed distance into the glowing aura.
float3 auraFromSD(float3 sd3, float3 tint, float bright) {
    sd3 = max(sd3, float3(0.0)) + 1e-4;
    float3 core = clamp(INTENSITY / pow(sd3, float3(FALLOFF_P)), 0.0, 1.0);
    float3 edge = float3(1.0) - smoothstep(float3(FADE_START), float3(FADE_END), sd3);
    return core * edge * bright * tint;
}

// ---- 1. ORBIT — a nucleus with electrons on pulsing orbits ----
float fieldOrbit(float2 p, float t) {
    float d = length(p) - 0.05; // nucleus
    for (int i = 0; i < 5; i++) {
        float fi = float(i);
        float sp = 0.5 + 0.22 * fi;
        float ang = t * sp + fi * TAU / 5.0;
        float rr = 0.17 + 0.09 * sin(t * 0.5 + fi);
        float2 pos = float2(cos(ang), sin(ang)) * rr;
        float r = 0.03 + 0.008 * sin(t * 1.3 + fi);
        d = smin(d, length(p - pos) - r, 0.07);
    }
    return d;
}

// ---- 2. LAVA — blobs drifting and merging like a lava lamp. Kept smallish so
//        the glow stays soft; white and a touch faster. ----
float fieldLava(float2 p, float t) {
    float d = 1e5;
    for (int i = 0; i < 6; i++) {
        float fi = float(i);
        float seed = hash11(fi);
        float seed2 = hash11(fi + 7.0);
        float x = 0.30 * sin(t * 0.42 + seed * TAU) + 0.10 * sin(t * 0.85 + seed2 * TAU);
        float y = 0.40 * sin(t * 0.30 * (0.7 + seed) + fi * 1.7);
        float r = 0.055 + 0.022 * sin(t * 0.5 + fi);
        d = smin(d, length(p - float2(x, y)) - r, 0.16);
    }
    return d;
}

// ---- WAVE — a flowing waveform line. Thicker and more playful: faster,
//        with a gentle vertical bob and stronger swing. ----
float fieldWave(float2 p, float t) {
    float amp = smoothstep(1.1, 0.0, abs(p.x));
    float bob = 0.05 * sin(t * 1.3);
    float y = bob + (0.22 * sin(p.x * 2.6 + t * 1.9)
             + 0.10 * sin(p.x * 5.0 - t * 1.4)
             + 0.05 * sin(p.x * 9.0 + t * 1.0)) * amp;
    float sd = abs(p.y - y) - 0.018; // thicker band
    sd += (1.0 - amp) * 0.22;        // dim toward the ends
    return sd;
}

// ---- 5. SWARM — fireflies drifting, gathering and dispersing ----
float fieldSwarm(float2 p, float t) {
    float d = 1e5;
    float gather = 0.5 + 0.5 * sin(t * 0.4);
    for (int i = 0; i < 9; i++) {
        float fi = float(i);
        float s1 = hash11(fi);
        float s2 = hash11(fi + 13.3);
        float2 base = float2(sin(t * (0.3 + 0.2 * s1) + s1 * TAU),
                             cos(t * (0.25 + 0.2 * s2) + s2 * TAU));
        float2 pos = base * mix(0.45, 0.10, gather);
        float r = 0.018 + 0.006 * sin(t * 2.0 + s1 * 6.0);
        d = smin(d, length(p - pos) - r, 0.05);
    }
    return d;
}

fragment float4 variantOrbitFragment(FluidVSOut in [[stage_in]],
                                     constant FluidUniforms& u [[buffer(0)]]) {
    float2 fragCoord = float2(in.position.x, u.iResolution.y - in.position.y);
    float2 res = u.iResolution;
    float2 p = (2.0 * fragCoord - res) / min(res.x, res.y);
    float t = u.iTime;
    p /= 1.0 + 0.03 * sin(t);
    float2 dir = normalizeSafe(p);
    float3 sd3 = float3(fieldOrbit(p - SPECTRAL.r * dir, t),
                        fieldOrbit(p - SPECTRAL.g * dir, t),
                        fieldOrbit(p - SPECTRAL.b * dir, t));
    float3 tint = mix(float3(1.0), hue2rgb(0.55 + 0.05 * sin(t * 0.3)), 0.10);
    float3 col = auraFromSD(sd3, tint, 1.0);
    col = pow(col, float3(1.0 / 1.2));
    col = min(col, 1.0);
    col += (fract(sin(dot(fragCoord, float2(12.9898, 78.233))) * 43758.5453) - 0.5) / 255.0;
    return float4(col, 1.0);
}

fragment float4 variantLavaFragment(FluidVSOut in [[stage_in]],
                                    constant FluidUniforms& u [[buffer(0)]]) {
    float2 fragCoord = float2(in.position.x, u.iResolution.y - in.position.y);
    float2 res = u.iResolution;
    float2 p = (2.0 * fragCoord - res) / min(res.x, res.y);
    float t = u.iTime;
    p /= 1.0 + 0.03 * sin(t);
    float2 dir = normalizeSafe(p);
    float3 sd3 = float3(fieldLava(p - SPECTRAL.r * dir, t),
                        fieldLava(p - SPECTRAL.g * dir, t),
                        fieldLava(p - SPECTRAL.b * dir, t));
    float3 tint = mix(float3(1.0), hue2rgb(0.60), 0.03); // white, faint cool
    float3 col = auraFromSD(sd3, tint, 1.0);
    col = pow(col, float3(1.0 / 1.2));
    col = min(col, 1.0);
    col += (fract(sin(dot(fragCoord, float2(12.9898, 78.233))) * 43758.5453) - 0.5) / 255.0;
    return float4(col, 1.0);
}

fragment float4 variantWaveFragment(FluidVSOut in [[stage_in]],
                                    constant FluidUniforms& u [[buffer(0)]]) {
    float2 fragCoord = float2(in.position.x, u.iResolution.y - in.position.y);
    float2 res = u.iResolution;
    float2 p = (2.0 * fragCoord - res) / min(res.x, res.y);
    float t = u.iTime;
    p /= 1.0 + 0.03 * sin(t);
    float2 dir = float2(0.0, 1.0); // aberration along the wave's vertical
    float3 sd3 = float3(fieldWave(p - SPECTRAL.r * dir, t),
                        fieldWave(p - SPECTRAL.g * dir, t),
                        fieldWave(p - SPECTRAL.b * dir, t));
    float3 tint = mix(float3(1.0), hue2rgb(0.60), 0.06);
    float3 col = auraFromSD(sd3, tint, 1.0);
    col = pow(col, float3(1.0 / 1.2));
    col = min(col, 1.0);
    col += (fract(sin(dot(fragCoord, float2(12.9898, 78.233))) * 43758.5453) - 0.5) / 255.0;
    return float4(col, 1.0);
}

fragment float4 variantSwarmFragment(FluidVSOut in [[stage_in]],
                                     constant FluidUniforms& u [[buffer(0)]]) {
    float2 fragCoord = float2(in.position.x, u.iResolution.y - in.position.y);
    float2 res = u.iResolution;
    float2 p = (2.0 * fragCoord - res) / min(res.x, res.y);
    float t = u.iTime;
    p /= 1.0 + 0.03 * sin(t);
    float2 dir = normalizeSafe(p);
    float3 sd3 = float3(fieldSwarm(p - SPECTRAL.r * dir, t),
                        fieldSwarm(p - SPECTRAL.g * dir, t),
                        fieldSwarm(p - SPECTRAL.b * dir, t));
    float3 tint = mix(float3(1.0), hue2rgb(0.60), 0.05); // white, faint cool
    float3 col = auraFromSD(sd3, tint, 1.05);
    col = pow(col, float3(1.0 / 1.2));
    col = min(col, 1.0);
    col += (fract(sin(dot(fragCoord, float2(12.9898, 78.233))) * 43758.5453) - 0.5) / 255.0;
    return float4(col, 1.0);
}

// ---- SPIRAL (orbit family) — dots tracing a rotating spiral arm ----
float fieldSpiral(float2 p, float t) {
    float d = 1e5;
    for (int i = 0; i < 7; i++) {
        float fi = float(i);
        float f = fi / 7.0;
        float ang = f * TAU * 1.5 + t * 1.1;
        float rad = 0.05 + f * 0.32 + 0.03 * sin(t * 0.8 + fi);
        float2 pos = float2(cos(ang), sin(ang)) * rad;
        float r = 0.022 + 0.006 * sin(t * 1.5 + fi);
        d = smin(d, length(p - pos) - r, 0.06);
    }
    return d;
}

// ---- MERCURY (lava family) — many small droplets, heavy merge, liquid metal ----
float fieldMercury(float2 p, float t) {
    float d = 1e5;
    float gather = 0.5 + 0.5 * sin(t * 0.6);
    for (int i = 0; i < 10; i++) {
        float fi = float(i);
        float s1 = hash11(fi);
        float s2 = hash11(fi + 5.0);
        float2 pos = float2(0.45 * sin(t * (0.4 + 0.3 * s1) + s1 * TAU),
                            0.45 * cos(t * (0.35 + 0.3 * s2) + s2 * TAU))
                     * mix(0.7, 1.0, gather);
        float r = 0.040 + 0.015 * sin(t * 0.8 + fi);
        d = smin(d, length(p - pos) - r, 0.18);
    }
    return d;
}

// ---- RIBBON (wave family) — two ribbons weaving past each other ----
float fieldRibbon(float2 p, float t) {
    float amp = smoothstep(1.1, 0.0, abs(p.x));
    float y1 = (0.18 * sin(p.x * 3.0 + t * 2.0) + 0.06 * sin(p.x * 6.0 - t * 1.5)) * amp + 0.10 * sin(t * 1.3);
    float y2 = (0.18 * sin(p.x * 3.0 - t * 2.0 + 1.5)) * amp - 0.10 * sin(t * 1.3);
    float d1 = abs(p.y - y1) - 0.012;
    float d2 = abs(p.y - y2) - 0.012;
    float sd = smin(d1, d2, 0.06);
    sd += (1.0 - amp) * 0.22;
    return sd;
}

// ---- BURST (swarm family) — a ring of dots breathing outward and back ----
float fieldBurst(float2 p, float t) {
    float d = 1e5;
    float pr = 0.10 + 0.30 * (0.5 + 0.5 * sin(t * 1.2));
    for (int i = 0; i < 12; i++) {
        float fi = float(i);
        float ang = fi / 12.0 * TAU + t * 0.2;
        float jitter = 0.04 * sin(t * 2.0 + fi * 1.7);
        float2 pos = float2(cos(ang), sin(ang)) * (pr + jitter);
        d = smin(d, length(p - pos) - 0.020, 0.04);
    }
    return d;
}

fragment float4 variantSpiralFragment(FluidVSOut in [[stage_in]],
                                      constant FluidUniforms& u [[buffer(0)]]) {
    float2 fragCoord = float2(in.position.x, u.iResolution.y - in.position.y);
    float2 res = u.iResolution;
    float2 p = (2.0 * fragCoord - res) / min(res.x, res.y);
    float t = u.iTime;
    p /= 1.0 + 0.03 * sin(t);
    float2 dir = normalizeSafe(p);
    float3 sd3 = float3(fieldSpiral(p - SPECTRAL.r * dir, t),
                        fieldSpiral(p - SPECTRAL.g * dir, t),
                        fieldSpiral(p - SPECTRAL.b * dir, t));
    float3 tint = mix(float3(1.0), hue2rgb(0.60), 0.05);
    float3 col = auraFromSD(sd3, tint, 1.0);
    col = pow(col, float3(1.0 / 1.2));
    col = min(col, 1.0);
    col += (fract(sin(dot(fragCoord, float2(12.9898, 78.233))) * 43758.5453) - 0.5) / 255.0;
    return float4(col, 1.0);
}

fragment float4 variantMercuryFragment(FluidVSOut in [[stage_in]],
                                       constant FluidUniforms& u [[buffer(0)]]) {
    float2 fragCoord = float2(in.position.x, u.iResolution.y - in.position.y);
    float2 res = u.iResolution;
    float2 p = (2.0 * fragCoord - res) / min(res.x, res.y);
    float t = u.iTime;
    p /= 1.0 + 0.03 * sin(t);
    float2 dir = normalizeSafe(p);
    float3 sd3 = float3(fieldMercury(p - SPECTRAL.r * dir, t),
                        fieldMercury(p - SPECTRAL.g * dir, t),
                        fieldMercury(p - SPECTRAL.b * dir, t));
    float3 tint = mix(float3(1.0), hue2rgb(0.60), 0.03);
    float3 col = auraFromSD(sd3, tint, 1.0);
    col = pow(col, float3(1.0 / 1.2));
    col = min(col, 1.0);
    col += (fract(sin(dot(fragCoord, float2(12.9898, 78.233))) * 43758.5453) - 0.5) / 255.0;
    return float4(col, 1.0);
}

fragment float4 variantRibbonFragment(FluidVSOut in [[stage_in]],
                                      constant FluidUniforms& u [[buffer(0)]]) {
    float2 fragCoord = float2(in.position.x, u.iResolution.y - in.position.y);
    float2 res = u.iResolution;
    float2 p = (2.0 * fragCoord - res) / min(res.x, res.y);
    float t = u.iTime;
    p /= 1.0 + 0.03 * sin(t);
    float2 dir = float2(0.0, 1.0);
    float3 sd3 = float3(fieldRibbon(p - SPECTRAL.r * dir, t),
                        fieldRibbon(p - SPECTRAL.g * dir, t),
                        fieldRibbon(p - SPECTRAL.b * dir, t));
    float3 tint = mix(float3(1.0), hue2rgb(0.60), 0.06);
    float3 col = auraFromSD(sd3, tint, 1.0);
    col = pow(col, float3(1.0 / 1.2));
    col = min(col, 1.0);
    col += (fract(sin(dot(fragCoord, float2(12.9898, 78.233))) * 43758.5453) - 0.5) / 255.0;
    return float4(col, 1.0);
}

fragment float4 variantBurstFragment(FluidVSOut in [[stage_in]],
                                     constant FluidUniforms& u [[buffer(0)]]) {
    float2 fragCoord = float2(in.position.x, u.iResolution.y - in.position.y);
    float2 res = u.iResolution;
    float2 p = (2.0 * fragCoord - res) / min(res.x, res.y);
    float t = u.iTime;
    p /= 1.0 + 0.03 * sin(t);
    float2 dir = normalizeSafe(p);
    float3 sd3 = float3(fieldBurst(p - SPECTRAL.r * dir, t),
                        fieldBurst(p - SPECTRAL.g * dir, t),
                        fieldBurst(p - SPECTRAL.b * dir, t));
    float3 tint = mix(float3(1.0), hue2rgb(0.60), 0.05);
    float3 col = auraFromSD(sd3, tint, 1.05);
    col = pow(col, float3(1.0 / 1.2));
    col = min(col, 1.0);
    col += (fract(sin(dot(fragCoord, float2(12.9898, 78.233))) * 43758.5453) - 0.5) / 255.0;
    return float4(col, 1.0);
}

// ============================================================================
// LEARNING / TOUCH — inverted (cream background, dark ink metaballs).
// Driven by touch: the cluster follows the finger, dots gather and merge into
// the blob as you hold (holdProgress), and fully collapse into one form during
// the "understanding" settle (release). The pre-first-podcast ritual.
// ============================================================================

struct TouchUniforms {
    float2 iResolution;
    float2 touch;        // destination (finger) in the same normalized space as p
    float iTime;
    float holdProgress;  // 0..1
    float touchActive;   // 0..1 — eased finger-down (destination strength)
    float release;       // 0..1 — the understanding / settle phase
    float dissolve;      // 0..1 — final grand dissolve into the podcast
};

// Soft inverted glow — the white-on-black aura flipped to dark-on-cream: a solid
// dark core with a gentle luminous falloff. No hard edge, no rings.
float learnGlow(float sd) {
    float s = max(sd, 0.0) + 1e-4;
    float core = clamp(0.0050 / pow(s, 1.15), 0.0, 1.0); // softer falloff = blurrier
    float edge = 1.0 - smoothstep(0.02, 0.62, s);        // wider, gentler halo
    return core * edge;
}

// Spring travel: an on-ramp (slow start, then accelerate) with a small overshoot
// near arrival so the dots "bounce" as they hit the center mass.
float springTravel(float ph) {
    float e = ph * ph; // on-ramp
    float bump = 0.07 * sin(ph * 3.14159) * smoothstep(0.55, 1.0, ph);
    return e + bump;
}

// Metaball field: a core orb at the destination plus streamer dots that emanate
// from FIXED sources and travel to the destination (the finger). They stretch
// into ovals (velocity drag) as they speed inward.
float learnField(float2 p, float2 center, float hold, float rel, float t) {
    float grow = 0.65 + 0.45 * hold + 0.5 * rel;
    float coreR = (0.12 + 0.06 * hold + 0.11 * rel) * grow;

    // Mercury core: wobbling sub-blobs merged heavily -> a living liquid-metal mass.
    float d = 1e5;
    for (int j = 0; j < 4; j++) {
        float fj = float(j);
        float a = fj / 4.0 * TAU + t * 0.5;
        float wob = coreR * 0.42 * (0.55 + 0.45 * sin(t * 1.3 + fj * 2.1));
        float2 cp = center + float2(cos(a), sin(a)) * wob;
        float cr = coreR * (0.60 + 0.18 * sin(t * 1.7 + fj));
        d = smin(d, length(p - cp) - cr, coreR * 0.95);
    }

    float speed = 0.45 + 1.2 * hold;
    for (int i = 0; i < 7; i++) {
        float fi = float(i);
        float gate = smoothstep(fi - 0.5, fi + 0.6, hold * 7.5); // continuous fade-in, no popping
        if (gate < 0.002) continue;
        float seed = hash11(fi);
        float seed2 = hash11(fi + 11.0);

        // FIXED source.
        float sang = seed * TAU;
        float2 src = float2(cos(sang), sin(sang)) * (1.05 + 0.20 * seed2);

        float ph = fract(t * speed * (0.7 + 0.6 * seed) + seed);
        float tr = mix(springTravel(ph), 1.0, rel);   // release pulls every streamer fully to center
        float2 pos = mix(src, center, clamp(tr, 0.0, 1.06));

        float fade = smoothstep(0.0, 0.05, ph);
        float rr = (0.05 + 0.012 * tr) * grow * fade * gate;
        if (rr < 0.003) continue;

        // Velocity stretch into ovals along the travel direction, more as it speeds in.
        float2 vdir = normalizeSafe(center - src);
        float2 q = p - pos;
        float2 ql = float2(q.x * vdir.x + q.y * vdir.y, -q.x * vdir.y + q.y * vdir.x);
        float stretch = 0.4 * smoothstep(0.2, 0.95, tr);
        ql.x /= (1.0 + stretch);
        ql.y *= (1.0 + 0.4 * stretch);

        d = smin(d, length(ql) - rr, 0.11);            // gooier merge into the mercury mass
    }
    d -= 0.006 * rel * sin(t * 2.0);
    return d;
}

fragment float4 learningTouchFragment(FluidVSOut in [[stage_in]],
                                      constant TouchUniforms& u [[buffer(0)]]) {
    float2 fragCoord = float2(in.position.x, u.iResolution.y - in.position.y);
    float2 res = u.iResolution;
    float2 p = (2.0 * fragCoord - res) / min(res.x, res.y);
    float t = u.iTime;
    float swell = u.holdProgress;
    float lv = u.dissolve; // launch progress, used as a velocity proxy

    float2 center = mix(float2(0.0, 0.0), u.touch, u.touchActive);
    // The exit: the whole mercury orb accelerates UP and off the top of the phone
    // (instead of fading), pulling its streamers with it. Then the podcast appears.
    center.y += lv * lv * 3.4; // accelerate up, faster

    // Sample the field in a warped space:
    //  - a slow anisotropic jiggle on x/y that grows with size (water pooling, surface tension)
    //  - vertical elongation into an oval as it launches (inertia)
    float warp = 0.07 * (0.35 + 0.65 * swell) * sin(t * 1.7) * (1.0 - lv); // jiggle eases off as it launches
    float fx = 1.0 + warp + 0.12 * lv;            // slight narrowing in x
    float fy = (1.0 - warp) / (1.0 + 0.38 * lv);  // gentle trailing oval — stays mostly round
    float2 q0 = p - center;
    q0.x *= fx;
    q0.y *= fy;
    float2 ps = center + q0;

    // Gentle chromatic fringe only — fewer visible rings.
    float2 dir = normalizeSafe(p - center);
    float aberr = 0.004 + 0.005 * swell;
    float gR = learnGlow(learnField(ps - dir * aberr, center, swell, u.release, t));
    float gG = learnGlow(learnField(ps,               center, swell, u.release, t));
    float gB = learnGlow(learnField(ps + dir * aberr, center, swell, u.release, t));

    float3 cream = float3(0.929, 0.918, 0.886);
    float3 ink   = float3(0.063, 0.055, 0.051);
    float3 glow = float3(gR, gG, gB);
    float3 col = cream - glow * (cream - ink);

    col += (fract(sin(dot(fragCoord, float2(12.9898, 78.233))) * 43758.5453) - 0.5) / 255.0;
    return float4(col, 1.0);
}
