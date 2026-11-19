// Shared driver for the IGLU texture-loader harnesses: hand the fuzz input to a texture loader
// factory exactly as an app does with a file it read (shell/shared/imageLoader/ImageLoader.cpp), then
// decode it into CPU memory with the loader's public load()/loadToExternalMemory().
#pragma once

#include <IGLU/texture_loader/ITextureLoader.h>
#include <IGLU/texture_loader/ITextureLoaderFactory.h>
#include <IGLU/texture_loader/IData.h>
#include <igl/Common.h>

#include <cstddef>
#include <cstdint>
#include <limits>
#include <vector>

namespace mayhem {

// Decoded images larger than this are not materialized (memorySizeInBytes() is the loader's own
// size computation; a 64 KiB file may legitimately describe a multi-GB texture, which is an OOM, not
// a memory-safety bug).
constexpr uint32_t kMaxDecodedBytes = 64u << 20;

inline int runTextureLoader(const iglu::textureloader::ITextureLoaderFactory& factory,
                            const uint8_t* data,
                            size_t size,
                            igl::TextureFormat preferredFormat = igl::TextureFormat::Invalid) {
  // tryCreate() takes a uint32_t length (ITextureLoaderFactory.h).
  if (size == 0 || size > std::numeric_limits<uint32_t>::max()) {
    return -1;
  }
  // Own copy so the loader's reads are bounded by ASan exactly at the input's end.
  std::vector<uint8_t> buf(data, data + size);
  igl::Result result;
  (void)factory.canCreate(buf.data(), static_cast<uint32_t>(buf.size()), &result);
  auto loader = factory.tryCreate(buf.data(), static_cast<uint32_t>(buf.size()), preferredFormat, &result);
  if (!loader || !result.isOk()) {
    return 0;
  }
  const auto& desc = loader->descriptor();
  (void)desc;
  (void)loader->mipLevelBytes();
  (void)loader->shouldGenerateMipmaps();
  const uint32_t bytes = loader->memorySizeInBytes();
  if (bytes == 0 || bytes > kMaxDecodedBytes) {
    return 0;
  }
  igl::Result loadResult;
  auto decoded = loader->load(&loadResult);
  // The decoded IData is not dereferenced here: any read of it belongs to the loader's own consumer
  // path (loadToExternalMemory below), so a defect is attributed to IGLU, not to this harness.
  (void)decoded;
  (void)loadResult;
  std::vector<uint8_t> external(bytes);
  igl::Result extResult;
  loader->loadToExternalMemory(external.data(), bytes, &extResult);
  return 0;
}

} // namespace mayhem
