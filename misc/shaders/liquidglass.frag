// Copyright (C) 2026 UnionTech Software Technology Co., Ltd.
// SPDX-License-Identifier: Apache-2.0 OR LGPL-3.0-only OR GPL-2.0-only OR GPL-3.0-only

#version 440

// WebGL Liquid Glass fragment shader ported from
// https://github.com/zccrs/liquid-glass/blob/main/webgl.html .
// The shader owns refraction/tint/specular only; blur and shadow are handled
// by Qt Quick MultiEffect / callers.

layout(location = 0) in vec2 qt_TexCoord0;
layout(location = 0) out vec4 fragColor;

layout(std140, binding = 0) uniform buf {
    mat4 qt_Matrix;
    float qt_Opacity;
    vec2 itemSize;
    vec2 lightDirection;
    float radius;
    float bezelWidth;
    float thickness;
    float ior;
    float specular;
    float tint;
    float dispersion;        // max RGB channel separation in px (0 disables)
    float dispersionWidth;   // absolute width of the chromatic rim band in pixels (0 disables)
    float dispersionBlend;   // 0=off .. 1=full per-channel refraction
} ubuf;

layout(binding = 1) uniform sampler2D source;

float sdRoundedRect(vec2 p, vec2 halfSize, float r)
{
    float rr = min(max(r, 0.0), min(halfSize.x, halfSize.y));
    vec2 q = abs(p) - halfSize + rr;
    return min(max(q.x, q.y), 0.0) + length(max(q, vec2(0.0))) - rr;
}

float surfaceHeight(float t)
{
    float s = 1.0 - t;
    return pow(1.0 - s * s * s * s, 0.25);
}

vec3 sampleBg(vec2 uv)
{
    return texture(source, clamp(uv, vec2(0.001), vec2(0.999))).rgb;
}

vec3 sampleBgSoft(vec2 uv, vec2 resolution, float radiusPx)
{
    if (radiusPx < 0.01)
        return sampleBg(uv);

    vec2 px = vec2(radiusPx) / max(resolution, vec2(1.0));
    vec3 color = sampleBg(uv) * 0.36;
    color += sampleBg(uv + vec2(px.x, 0.0)) * 0.16;
    color += sampleBg(uv - vec2(px.x, 0.0)) * 0.16;
    color += sampleBg(uv + vec2(0.0, px.y)) * 0.16;
    color += sampleBg(uv - vec2(0.0, px.y)) * 0.16;
    return color;
}

void main()
{
    vec2 size = max(ubuf.itemSize, vec2(1.0));
    vec2 p = qt_TexCoord0 * size - size * 0.5;
    vec2 halfSize = size * 0.5;

    float sd = sdRoundedRect(p, halfSize, ubuf.radius);
    float aa = max(fwidth(sd) * 2.5, 1.75);

    // Cull only pixels fully outside the AA band; pixels in [0, aa] still
    // need to compute a fractional alpha for proper edge anti-aliasing.
    if (sd > aa) {
        fragColor = vec4(0.0);
        return;
    }

    float distFromEdge = -sd;
    float bezel = min(ubuf.bezelWidth, min(ubuf.radius, min(halfSize.x, halfSize.y)) - 1.0);
    bezel = max(bezel, 1.0);
    float t = clamp(distFromEdge / bezel, 0.0, 1.0);

    float h = surfaceHeight(t);
    float dt = 0.001;
    float h2 = surfaceHeight(min(t + dt, 1.0));
    float dh = (h2 - h) / dt;

    // Outer ease-in: the squircle derivative peaks at the silhouette (→∞).
    // Without this, UV warp slams to max just inside the coverage edge and
    // high-contrast backdrop edges grow triangular spikes / black diagonal
    // lines at corners, especially when radius is small.
    float outerSoft = smoothstep(0.0, max(2.5 * aa, 2.5), distFromEdge);
    dh *= outerSoft;

    float slopeAngle = atan(dh * (max(ubuf.thickness, 0.0) / bezel));
    float sinR = sin(slopeAngle) / max(ubuf.ior, 1.0001);
    sinR = clamp(sinR, -1.0, 1.0);
    float thetaR = asin(sinR);
    float displacement = h * max(ubuf.thickness, 0.0) * (tan(slopeAngle) - tan(thetaR));

    // Centered finite-difference gradient (NOT forward).
    // sdRoundedRect uses max(q.x, q.y); its forward one-sided derivative is 0
    // on the 45° diagonal (q.x == q.y) in the interior, making grad == vec2(0)
    // and normalize() return NaN → black diagonal line.  Centered diff gives
    // the correct symmetric average, non-zero on the diagonal.
    vec2 grad;
    float eps = 0.5;
    grad.x = sdRoundedRect(p + vec2(eps, 0.0), halfSize, ubuf.radius)
           - sdRoundedRect(p - vec2(eps, 0.0), halfSize, ubuf.radius);
    grad.y = sdRoundedRect(p + vec2(0.0, eps), halfSize, ubuf.radius)
           - sdRoundedRect(p - vec2(0.0, eps), halfSize, ubuf.radius);
    // Guard against zero-length gradient (shape center): leave grad as (0,0)
    // so refraction/dispersion/specular all degenerate to "no effect", not NaN.
    float gradLen = length(grad);
    grad = gradLen > 1e-6 ? grad / gradLen : vec2(0.0);

    vec2 refractedUV = qt_TexCoord0 - grad * displacement / size;
    float edgeFilterPx = 2.0 * (1.0 - smoothstep(0.0, max(aa * 4.0, 4.0), distFromEdge));
    vec3 color = sampleBgSoft(refractedUV, size, edgeFilterPx);

    // Chromatic dispersion: split the rim refraction sample per channel along
    // the refraction gradient by a pixel spread (blue bends furthest inward),
    // blended in only near the curved edge so flat interior colour is untouched.
    // The hue follows geometry (grad) + background content, never a fixed colour.
    float spread = clamp(ubuf.dispersion, 0.0, 400.0);
    float fringeWidth = max(ubuf.dispersionWidth, 0.0);
    float edgeInfluence = 1.0 - smoothstep(0.0, max(fringeWidth, 0.5), distFromEdge);
    if (fringeWidth <= 0.0) {
        edgeInfluence = 0.0;
    }
    edgeInfluence *= clamp(ubuf.dispersionBlend, 0.0, 1.0);
    float off = spread * edgeInfluence;

    if (off > 0.5) {
        vec2 uvR = qt_TexCoord0 - grad * max(0.0, displacement - off) / size;
        vec2 uvB = qt_TexCoord0 - grad * (displacement + off) / size;
        vec3 dispersedColor = vec3(sampleBg(uvR).r, color.g, sampleBg(uvB).b);
        color = mix(color, dispersedColor, edgeInfluence);
    }

    vec2 lightDir = normalize(ubuf.lightDirection);
    float rimDot = abs(dot(grad, lightDir));
    float rimFalloff = 1.0 - smoothstep(0.0, bezel * 0.4, distFromEdge);
    float specHighlight = pow(rimDot * rimFalloff, 1.5);
    color += vec3(specHighlight * clamp(ubuf.specular, 0.0, 1.0));

    float innerShadow = 1.0 - smoothstep(0.0, bezel * 0.6, distFromEdge);
    color *= mix(1.0, 0.7, innerShadow * 0.3);

    float innerRim = smoothstep(0.0, 2.0, distFromEdge)
        * (1.0 - smoothstep(2.0, 5.0, distFromEdge));
    color += vec3(innerRim * 0.15 * clamp(ubuf.specular, 0.0, 1.0));

    // Symmetric AA: alpha ramps from 0 (sd=+aa, fully outside) through 0.5
    // (sd=0, exact silhouette) to 1.0 (sd=-aa, fully inside).  This covers
    // both sides of the edge, unlike a one-sided smoothstep on distFromEdge.
    float alpha = (1.0 - smoothstep(-aa, aa, sd)) * ubuf.qt_Opacity;

    // Manual mix for tint: GLSL mix(color, vec3(1.0), uniform) is mis-optimized
    // by Mesa llvmpipe (constant-folds away the uniform branch).  Expanding it
    // avoids the dead-code elimination that was zeroing the tint contribution.
    float tintFactor = clamp(ubuf.tint, 0.0, 1.0);
    color = color * (1.0 - tintFactor) + vec3(1.0) * tintFactor;
    fragColor = vec4(clamp(color, 0.0, 1.0) * alpha, alpha);
}
