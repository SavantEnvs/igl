// SPIR-V modules through IGL's hand-written SPIR-V walkers used by the Vulkan backend when a shader
// module is created: getReflectionData() and specializeConstants() (src/igl/vulkan/util).
#include <igl/vulkan/util/SpvConstantSpecialization.h>
#include <igl/vulkan/util/SpvReflection.h>

#include <cstddef>
#include <cstdint>
#include <cstring>
#include <vector>

extern "C" int LLVMFuzzerTestOneInput(const uint8_t* data, size_t size) {
  // A SPIR-V module is a stream of 32-bit words; both APIs take a uint32_t pointer + byte count.
  // Precondition from the format: a SPIR-V module starts with a 5-word header (SPIR-V spec 2.3,
  // "Physical Layout of a SPIR-V Module and Instruction"), and Vulkan requires codeSize to be a
  // multiple of 4 and pCode to be a SPIR-V module (VkShaderModuleCreateInfo valid usage), which is
  // what IGL's Device::createShaderModule hands to these functions. Shorter inputs are not modules.
  const size_t numWords = size / sizeof(uint32_t);
  if (numWords < 5) {
    return -1;
  }
  std::vector<uint32_t> words(numWords);
  std::memcpy(words.data(), data, numWords * sizeof(uint32_t));
  const size_t numBytes = numWords * sizeof(uint32_t);

  const auto info = igl::vulkan::util::getReflectionData(words.data(), numBytes);
  (void)igl::vulkan::util::mergeReflectionData(info, info);

  const std::vector<uint32_t> original = words;
  igl::vulkan::util::specializeConstants(words.data(), numBytes, {1u, 0u, 0xFFFFFFFFu, 42u});
  // The specialized module is what the backend hands on; reflect it again, but only when
  // specialization rewrote an instruction (otherwise it is the module reflected above).
  if (words != original) {
    (void)igl::vulkan::util::getReflectionData(words.data(), numBytes);
  }
  return 0;
}
