
@group(2) @binding(0) var destImage : texture_storage_2d<rgba8unorm, write>;
@group(1) @binding(1) var<storage, read> colorBuf : array<vec4f>;

@compute @workgroup_size(1, 1, 1)
fn imageStoreOrange(@builtin(global_invocation_id) gid : vec3u) {
  textureStore(destImage, vec2i(gid.xy), colorBuf[0]);
}
