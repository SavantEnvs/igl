
struct Uniforms { color : vec4f, };
@group(1) @binding(3) var<uniform> uniforms : Uniforms;

@fragment
fn main() -> @location(0) vec4f {
  return uniforms.color;
}
