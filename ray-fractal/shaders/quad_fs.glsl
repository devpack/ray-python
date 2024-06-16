#version 430 core

uniform sampler2D quad_tex;

in vec2 uvs;
out vec4 f_color;

void main() {
    f_color = vec4(texture(quad_tex, uvs).rgb, 1.0);
}