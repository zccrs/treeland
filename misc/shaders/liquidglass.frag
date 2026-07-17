// Copyright (C) 2026 UnionTech Software Technology Co., Ltd.
// SPDX-License-Identifier: Apache-2.0 OR LGPL-3.0-only OR GPL-2.0-only OR GPL-3.0-only

#version 440

// Liquid Glass fragment shader — ported from the OverShifted LiquidGlass
// reference (https://github.com/OverShifted/LiquidGlass).
//
// Model:
//   • Superellipse SDF defines the glass shape; powerFactor controls corner
//     curvature (→∞ squares, →2 circle). The shape fills the whole item.
//   • Radial refraction: sampleP = p * pow(f(dist), fPower), where
//     f(x) = 1 - b * (c·e)^(-d·x - a).  f crosses zero near the edge, so a
//     whole band collapses to the centre colour — the severe "point stretched
//     into a line" corner stretch real glass produces.  No IOR / bezel.
//   • Angular glow rim: sin(atan(...) - 0.5) * glowWeight * smoothstep band.
//   • Optional film grain noise.
//   • Blur + colour grading happen upstream in MultiEffect (not the shader).

layout(location = 0) in vec2 texCoord;
layout(location = 0) out vec4 fragColor;

layout(std140, binding = 0) uniform buf {
    mat4 qt_Matrix;
    float qt_Opacity;
    float powerFactor;   // superellipse exponent (shape corner curvature)
    float fPower;        // exponent on the refraction curve f(dist)
    float a;             // refraction curve param a
    float b;             // refraction curve param b
    float c;             // refraction curve param c
    float d;             // refraction curve param d
    float grainAmount;  // film grain amplitude
    float glowWeight;    // rim glow strength
    float glowBias;      // overall brightness bias
    float glowEdge0;     // glow smoothstep inner edge
    float glowEdge1;     // glow smoothstep outer edge
} ubuf;

layout(binding = 1) uniform sampler2D source;

const float M_E = 2.718281828459045;

// Superellipse signed distance (|x|^n + |y|^n - r^n) / (n·|∇|).
float sdSuperellipse(vec2 p, float n, float r)
{
    vec2 pa = abs(p);
    float numerator = pow(pa.x, n) + pow(pa.y, n) - pow(r, n);
    float denominator = n * sqrt(pow(pa.x, 2.0 * n - 2.0)
                                 + pow(pa.y, 2.0 * n - 2.0)) + 1e-5;
    return numerator / denominator;
}

// Refraction curve f(x) = 1 - b·(c·e)^(-d·x - a).
float f(float x)
{
    return 1.0 - ubuf.b * pow(ubuf.c * M_E, -ubuf.d * x - ubuf.a);
}

float rand(vec2 co)
{
    return fract(sin(dot(co, vec2(12.9898, 78.233))) * 43758.5453);
}

// Angular glow pattern sweeping around the shape.
float Glow(vec2 uv)
{
    return sin(atan(uv.y * 2.0 - 1.0, uv.x * 2.0 - 1.0) - 0.5);
}

vec4 sampleBackdrop(vec2 coord)
{
    return texture(source, clamp(coord, vec2(0.001), vec2(0.999)));
}

void main()
{
    vec2 p = (texCoord - vec2(0.5)) * 2.0;
    float dist = -sdSuperellipse(p, ubuf.powerFactor, 1.0);

    // Anti-aliased shape edge: smoothstep over ~1 pixel using screen-space
    // derivatives of the SDF.  Replaces the hard binary cut that caused jaggies.
    float edgeAA = fwidth(dist);
    float shapeAlpha = smoothstep(-edgeAA, edgeAA, dist);
    if (shapeAlpha <= 0.0) {
        fragColor = vec4(0.0);
        return;
    }

    // Radial refraction. f(dist) crosses zero near the edge; preserving the
    // sign while raising to fPower keeps the severe edge inversion without
    // producing NaN for fractional exponents on negative bases.
    float fv = f(dist);
    float s = sign(fv) * pow(abs(fv), ubuf.fPower);
    vec2 coord = (p * s) * 0.5 + vec2(0.5);

    // Interior anti-aliasing: only where refraction deviates from the
    // identity mapping (s ≠ 1) does the backdrop get stretched/compressed
    // and need a multi-tap blend.  |s-1| is the per-axis scale deviation,
    // so the centre (s≈1, identity) gets zero blur and stays sharp while
    // edges (s→0 or negative, severe inversion) get the most.  fwidth
    // gives the screen-space texel size.
    float texelAA = fwidth(texCoord.x);
    vec2 blurOff = vec2(texelAA) * abs(s - 1.0) * 1.5;
    vec4 c0 = sampleBackdrop(coord);
    vec4 c1 = sampleBackdrop(coord + vec2(blurOff.x, 0.0));
    vec4 c2 = sampleBackdrop(coord - vec2(blurOff.x, 0.0));
    vec4 c3 = sampleBackdrop(coord + vec2(0.0, blurOff.y));
    vec4 c4 = sampleBackdrop(coord - vec2(0.0, blurOff.y));
    vec4 color = (c0 + c1 + c2 + c3 + c4) * 0.2;
    color.rgb += vec3(rand(gl_FragCoord.xy) - 0.5) * ubuf.grainAmount;

    float glowStep = (abs(ubuf.glowEdge1 - ubuf.glowEdge0) < 1e-5)
        ? 0.0
        : smoothstep(ubuf.glowEdge0, ubuf.glowEdge1, dist);
    float mul = Glow(texCoord) * ubuf.glowWeight * glowStep + 1.0 + ubuf.glowBias;
    color.rgb *= mul;

    float alpha = shapeAlpha * ubuf.qt_Opacity;
    fragColor = vec4(clamp(color.rgb, 0.0, 1.0) * alpha, alpha);
}
