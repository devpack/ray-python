#version 330 core

layout (location=0) in vec3 vertexPosition;
layout (location=1) in vec4 vertexColor;

out vec4 fragColor;

void main()
{
    gl_Position = vec4(vertexPosition, 1.0);
    fragColor = vertexColor;
}