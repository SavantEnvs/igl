
struct Uniforms { m : mat3x3f, pad : array<vec4f, 300>, color : vec4f, };
@group(1) @binding(0) var<uniform> uniforms : Uniforms;

@fragment
fn main() -> @location(0) vec4f {
  return vec4f(uniforms.m[2], 1.0) * uniforms.color;
}
