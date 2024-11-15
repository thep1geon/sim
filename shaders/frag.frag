#version 330 core

uniform float time;
uniform sampler2D texture1;
uniform sampler2D texture2;

uniform vec3 object_color;
uniform vec3 light_color;

in vec2 uv;

out vec4 fragcolor;

void main() {
    // fragcolor = mix(texture(texture1, uv), texture(texture2, uv), 0.2);
    fragcolor = vec4(object_color * light_color, 1);
    fragcolor *= texture(texture1, uv);
}
