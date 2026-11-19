// KTX1 texture files through IGLU's public loader API:
// ktx1::TextureLoaderFactory::tryCreate() (header validate(), then libktx) -> load().
#include "texture_loader_common.h"

#include <IGLU/texture_loader/ktx1/TextureLoaderFactory.h>

extern "C" int LLVMFuzzerTestOneInput(const uint8_t* data, size_t size) {
  static const iglu::textureloader::ktx1::TextureLoaderFactory factory;
  return mayhem::runTextureLoader(factory, data, size);
}
