
@group(0) @binding(0) var shadowMap : texture_depth_2d;
@group(0) @binding(1) var shadowSampler : sampler_comparison;

@fragment
fn main(@location(0) uv : vec2f) -> @location(0) vec4f {
  return vec4f(textureSampleCompare(shadowMap, shadowSampler, uv, 0.5));
}
