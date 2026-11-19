
struct FragmentConstants { scale : vec4f, color : vec4f, };
@group(3) @binding(0) var<uniform> pc : FragmentConstants;
@fragment fn main() -> @location(0) vec4f {
  return pc.color;
}
