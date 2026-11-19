
enable f16;
/* block /* nested */ comment */
const kCount = 3u;
alias Color = vec4<f32>;

@group(1) @binding(0) var<uniform> uniforms : Uniforms;
@group(1) @binding(2) var<storage, read> particles : array<Particle>;
@group(1) @binding(3) var<storage, read_write> counters : Counters;
@group(0) @binding(0) var colorTex : texture_2d<f32>;
@group(0) @binding(1) var colorSampler : sampler;
@group(0) @binding(2) var depthTex : texture_depth_2d;
@group(0) @binding(3) var shadowSampler : sampler_comparison;
@group(0) @binding(4) var indexTex : texture_2d_array<u32>;
@group(0) @binding(6) var cubeTex : texture_cube<f32>;
@group(0) @binding(8) var msTex : texture_multisampled_2d<i32>;
@group(2) @binding(0) var outImage : texture_storage_2d<rgba8unorm, write>;
@group(3) @binding(0) var<uniform> pushConstants : vec4f;

var<private> scratch : vec4f;

@id(7) override kScale : f32 = 1.0;
override kEnabled : bool;

struct Particle {
  position : vec3f,
  mass : f32,
  color : Color,
  flags : vec2<u32>,
};

struct Counters {
  total : atomic<u32>,
  perBin : array<atomic<u32>, 4>,
};

struct Uniforms {
  mvp : mat4x4f,
  normal : mat3x3<f32>,
  tint : Color,
  offset : vec2f,
  @align(16) level : i32,
  weights : array<f32, kCount>,
  @size(32) enabled : u32,
  half : vec3h,
  small : mat2x2f,
};

struct VertexOut {
  @builtin(position) position : vec4f,
  @location(0) @interpolate(flat) id : u32,
};

fn helper(x : f32) -> f32 {
  if (x > 1.0) { return x >> 1; }
  return x;
}

@vertex
fn vs(@builtin(vertex_index) i : u32) -> VertexOut {
  return VertexOut(vec4f(0.0), i);
}

@fragment
fn fs(v : VertexOut) -> @location(0) vec4f {
  return textureSample(colorTex, colorSampler, vec2f(0.5));
}

@compute @workgroup_size(8, 4i)
fn cs() {}

@compute @workgroup_size(kCount, 2, 1)
fn cs2() {}
