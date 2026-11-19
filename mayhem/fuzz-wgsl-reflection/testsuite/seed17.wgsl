
struct VertexConstants { scale : vec4f, };
@group(3) @binding(0) var<uniform> pc : VertexConstants;
@vertex fn main(@location(0) p : vec4f) -> @builtin(position) vec4f {
  return vec4f(p.xyz * pc.scale.x, 1.0);
}
