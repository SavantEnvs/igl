// PNG / JPEG / Radiance HDR images through the aggregate iglu::textureloader::TextureLoaderFactory
// built from the stb factories, as shell/shared/imageLoader/ImageLoader.cpp does -> load().
#include "texture_loader_common.h"

#include <IGLU/texture_loader/TextureLoaderFactory.h>
#include <IGLU/texture_loader/stb_hdr/TextureLoaderFactory.h>
#include <IGLU/texture_loader/stb_jpeg/TextureLoaderFactory.h>
#include <IGLU/texture_loader/stb_png/TextureLoaderFactory.h>

#include <memory>
#include <vector>

namespace {
std::unique_ptr<iglu::textureloader::TextureLoaderFactory> makeFactory() {
  std::vector<std::unique_ptr<iglu::textureloader::ITextureLoaderFactory>> factories;
  factories.emplace_back(std::make_unique<iglu::textureloader::stb::hdr::TextureLoaderFactory>());
  factories.emplace_back(std::make_unique<iglu::textureloader::stb::jpeg::TextureLoaderFactory>());
  factories.emplace_back(std::make_unique<iglu::textureloader::stb::png::TextureLoaderFactory>());
  return std::make_unique<iglu::textureloader::TextureLoaderFactory>(std::move(factories));
}
} // namespace

extern "C" int LLVMFuzzerTestOneInput(const uint8_t* data, size_t size) {
  static const auto factory = makeFactory();
  return mayhem::runTextureLoader(*factory, data, size);
}
