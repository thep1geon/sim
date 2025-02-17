#version 330 core

layout (location = 0) in vec3 a_pos;
layout (location = 1) in vec2 a_uv;
layout (location = 2) in vec3 a_normal;

uniform float time;

uniform mat4 view;
uniform mat4 model;
uniform mat4 projection;

out vec2 uv;

void main() {
    vec4 pos = projection * view * model * vec4(a_pos, 1.0);
    pos.y += sin(time*3);
    pos.x += cos(time*3);
    uv = a_uv;
    gl_Position = pos;
}
