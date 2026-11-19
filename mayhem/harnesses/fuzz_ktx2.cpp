// KTX2 texture files (header, DFD, level index, supercompression; basis transcode when a preferred
// format is requested) through IGLU's ktx2::TextureLoaderFactory -> load().
#include "texture_loader_common.h"

#include <IGLU/texture_loader/ktx2/TextureLoaderFactory.h>

#include <igl/TextureFormat.h>

extern "C" int LLVMFuzzerTestOneInput(const uint8_t* data, size_t size) {
  static const iglu::textureloader::ktx2::TextureLoaderFactory factory;
  if (size < 1) {
    return -1;
  }
  // First byte picks the preferred format (the transcode target for Basis-supercompressed files);
  // the rest is the file.
  static constexpr igl::TextureFormat kPreferred[] = {
      igl::TextureFormat::Invalid,
      igl::TextureFormat::RGBA_UNorm8,
      igl::TextureFormat::RGBA_ASTC_4x4,
      igl::TextureFormat::RGBA_BC7_UNORM_4x4,
      igl::TextureFormat::RGB8_ETC2,
      igl::TextureFormat::RGBA_UNorm8,
      igl::TextureFormat::Invalid,
      igl::TextureFormat::Invalid,
  };
  const igl::TextureFormat preferred = kPreferred[data[0] % (sizeof(kPreferred) / sizeof(kPreferred[0]))];
  return mayhem::runTextureLoader(factory, data + 1, size - 1, preferred);
}
