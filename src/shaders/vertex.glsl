#version 330 core

layout(location = 0) in vec2 vPos;

uniform vec2 centerOffset;
uniform vec2 scaleFactor;

out vec2 pointCoords;

void main() {
  gl_Position = vec4(vPos, 0.0, 1.0);

  pointCoords = (vPos - centerOffset) * scaleFactor;
}
