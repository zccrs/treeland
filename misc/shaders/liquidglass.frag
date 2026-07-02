#version 440

layout(location = 0) in vec2 texCoord;
layout(location = 0) out vec4 fragColor;

layout(std140, binding = 0) uniform buf {
    mat4 qt_Matrix;
    float qt_Opacity;
    vec2 itemSize;
    float radius;
    float refractionHeight;
    float refractionAmount;
    float exposure;
    float saturation;
    vec4 tintColor;
    vec4 highlightColor;
    float highlightStrength;
} ubuf;

layout(binding = 1) uniform sampler2D source;

float roundedRectDistance(vec2 p, vec2 halfSize, float radius)
{
    float r = min(radius, min(halfSize.x, halfSize.y));
    vec2 q = abs(p) - halfSize + vec2(r);
    return length(max(q, vec2(0.0))) + min(max(q.x, q.y), 0.0) - r;
}

vec2 roundedRectNormal(vec2 p, vec2 halfSize, float radius)
{
    float r = min(radius, min(halfSize.x, halfSize.y));
    vec2 inner = halfSize - vec2(r);
    vec2 corner = clamp(p, -inner, inner);
    vec2 delta = p - corner;
    float len = length(delta);

    if (len > 0.0001)
        return delta / len;

    vec2 edge = halfSize - abs(p);
    if (edge.x < edge.y)
        return vec2(sign(p.x), 0.0);

    return vec2(0.0, sign(p.y));
}

vec3 applySaturation(vec3 color, float saturationValue)
{
    float luminance = dot(color, vec3(0.2126, 0.7152, 0.0722));
    return mix(vec3(luminance), color, saturationValue);
}

void main()
{
    vec2 size = max(ubuf.itemSize, vec2(1.0));
    vec2 pixel = texCoord * size;
    vec2 centered = pixel - size * 0.5;
    vec2 halfSize = size * 0.5;

    float distanceToEdge = -roundedRectDistance(centered, halfSize, ubuf.radius);
    vec2 normal = roundedRectNormal(centered, halfSize, ubuf.radius);
    float band = max(ubuf.refractionHeight, 0.001);
    float edgeMix = clamp(1.0 - distanceToEdge / band, 0.0, 1.0);
    edgeMix = edgeMix * edgeMix * (3.0 - 2.0 * edgeMix);

    float displacement = ubuf.refractionAmount * edgeMix;
    vec2 sampleCoord = texCoord + normal * displacement / size;
    sampleCoord = clamp(sampleCoord, vec2(0.001), vec2(0.999));

    vec4 backdrop = texture(source, sampleCoord);
    vec3 color = applySaturation(backdrop.rgb * ubuf.exposure, ubuf.saturation);
    color = mix(color, ubuf.tintColor.rgb, ubuf.tintColor.a);
    color += ubuf.highlightColor.rgb * ubuf.highlightColor.a * ubuf.highlightStrength * edgeMix;

    fragColor = vec4(clamp(color, vec3(0.0), vec3(1.0)), backdrop.a) * ubuf.qt_Opacity;
}
