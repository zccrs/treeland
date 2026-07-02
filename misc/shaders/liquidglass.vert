#version 440

layout(location = 0) in vec4 vertex;
layout(location = 1) in vec2 multiTexCoord;

layout(location = 0) out vec2 texCoord;

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

out gl_PerVertex { vec4 gl_Position; };

void main()
{
    texCoord = multiTexCoord;
    gl_Position = ubuf.qt_Matrix * vertex;
}
