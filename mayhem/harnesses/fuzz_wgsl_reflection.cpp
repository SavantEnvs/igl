// WGSL shader source through IGL's hand-written WGSL reflection parser (WebGPU backend):
// igl::webgpu::parseWgslReflection(), then the lookups the backend does on its result.
#include <igl/webgpu/WgslReflection.h>

#include <cstddef>
#include <cstdint>
#include <string>
#include <string_view>

extern "C" int LLVMFuzzerTestOneInput(const uint8_t* data, size_t size) {
  const std::string source(reinterpret_cast<const char*>(data), size);
  igl::webgpu::WgslReflection reflection;
  const igl::Result result = igl::webgpu::parseWgslReflection(source, reflection);
  if (!result.isOk()) {
    return 0;
  }
  for (const auto& ep : reflection.entryPoints) {
    (void)reflection.findEntryPoint(ep.name);
  }
  for (const auto& s : reflection.structs) {
    (void)reflection.findStruct(s.name);
  }
  for (const auto& b : reflection.bindings) {
    (void)reflection.findBinding(b.group, b.binding);
    (void)reflection.findStruct(b.type);
  }
  return 0;
}
