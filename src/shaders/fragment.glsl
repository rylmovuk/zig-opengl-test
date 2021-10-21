#version 330 core

in vec2 pointCoords;
out vec4 fragCol;

uniform uint iters;

// stolen from @gsass1 (github)
vec4 map_to_rgba(float t) {
  return vec4(
    8.5 * (1.0-t) * (1.0-t) * (1.0-t) * t,
    15.0 * (1.0-t) * (1.0-t) * t * t,
    9.0 * (1.0-t) * t * t * t,
    1.0
  );
}

void main() {
  uint i;
  vec2 z = pointCoords;

  for (i = 0u; i < iters; ++i) {
      if (dot(z, z) > 4.0) break;
      z = vec2(z.x * z.x - z.y * z.y, 2 * z.x * z.y) + pointCoords;
  }
  fragCol = map_to_rgba(float(i)/float(iters));
}
