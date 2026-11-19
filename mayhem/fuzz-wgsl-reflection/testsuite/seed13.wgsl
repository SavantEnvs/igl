
struct Uniforms { tint : vec4f, extra : array<vec4f, 3>, };
@group(0) @binding(0) var tex : texture_2d<f32>;
@group(0) @binding(1) var samp : sampler;
@group(1) @binding(0) var<uniform> uniforms : Uniforms;
@fragment
fn main(@location(0) uv : vec2f) -> @location(0) vec4f {
  return textureSample(tex, samp, uv) * uniforms.tint + uniforms.extra[0];
}
