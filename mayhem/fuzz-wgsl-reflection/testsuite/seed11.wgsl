
struct VertexOut {
  @builtin(position) position : vec4f,
  @location(0) color : vec3f,
};

var<private> positions : array<vec2f, 3> =
    array<vec2f, 3>(vec2f(-0.6, -0.4), vec2f(0.6, -0.4), vec2f(0.0, 0.6));
var<private> colors : array<vec3f, 3> =
    array<vec3f, 3>(vec3f(1.0, 0.0, 0.0), vec3f(0.0, 1.0, 0.0), vec3f(0.0, 0.0, 1.0));

@vertex
fn vertexMain(@builtin(vertex_index) i : u32) -> VertexOut {
  return VertexOut(vec4f(positions[i], 0.0, 1.0), colors[i]);
}

@fragment
fn fragmentMain(v : VertexOut) -> @location(0) vec4f {
  return vec4f(v.color, 1.0);
}
