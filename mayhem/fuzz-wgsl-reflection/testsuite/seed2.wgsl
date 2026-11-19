binding 0.0 colorTex texture texture_2d<f32> dim=2d sampled=0
binding 0.1 colorSampler sampler sampler
binding 0.2 depthTex depth-texture texture_depth_2d dim=2d sampled=0
binding 0.3 shadowSampler comparison-sampler sampler_comparison
binding 0.4 indexTex texture texture_2d_array<u32> dim=2d-array sampled=2
binding 0.6 cubeTex texture texture_cube<f32> dim=cube sampled=0
binding 0.8 msTex multisampled-texture texture_multisampled_2d<i32> dim=2d sampled=1
binding 1.0 uniforms uniform Uniforms size=224
binding 1.2 particles read-only-storage array<Particle> size=48
binding 1.3 counters storage Counters size=20
binding 2.0 outImage storage-texture texture_storage_2d<rgba8unorm, write> dim=2d sampled=0
binding 3.0 pushConstants uniform vec4f size=16
struct Particle size=48 align=16
  position : vec3f @0 size=12 align=16 igl=3
  mass : f32 @12 size=4 align=4 igl=1
  color : vec4<f32> @16 size=16 align=16 igl=4
  flags : vec2<u32> @32 size=8 align=8 igl=7
struct Counters size=20 align=4
  total : atomic<u32> @0 size=4 align=4 igl=6
  perBin : array<atomic<u32>, 4> @4 size=16 align=4 igl=6 len=4 stride=4
struct Uniforms size=224 align=16
  mvp : mat4x4f @0 size=64 align=16 igl=12
  normal : mat3x3<f32> @64 size=48 align=16 igl=11
  tint : vec4<f32> @112 size=16 align=16 igl=4
  offset : vec2f @128 size=8 align=8 igl=2
  level : i32 @144 size=4 align=16 igl=6
  weights : array<f32, kCount> @148 size=12 align=4 igl=1 len=3 stride=4
  enabled : u32 @160 size=32 align=4 igl=6
  half : vec3h @192 size=6 align=8 igl=0
  small : mat2x2f @200 size=16 align=8 igl=10
struct VertexOut size=32 align=16
  position : vec4f @0 size=16 align=16 igl=4
  id : u32 @16 size=4 align=4 igl=6
entry vs stage=0 wg=0,0,0
entry fs stage=1 wg=0,0,0
entry cs stage=2 wg=8,4,1
entry cs2 stage=2 wg=3,2,1
override kScale : f32 id=7
override kEnabled : bool
