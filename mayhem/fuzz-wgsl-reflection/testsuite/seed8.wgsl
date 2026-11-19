
@group(0) @binding(0) var tex : texture_2d<f32>;
@group(0) @binding(1) var samp : sampler;

@fragment
fn main(@builtin(position) position : vec4f) -> @location(0) vec4f {
  return textureSample(tex, samp, position.xy / 4.0);
}
