#include <cmath>
#include <cstdint>
#include <cstdio>
#include "mx_fp_math.h"

int main() {
  unsigned checked = 0;
  for (unsigned a = 0; a < 256; ++a) {
    if ((a & 127) == 127)
      continue;
    for (unsigned b = 0; b < 256; ++b) {
      if ((b & 127) == 127)
        continue;
      const float product = mx::fp8_e4m3_decode(a) * mx::fp8_e4m3_decode(b);
      // Finite E4M3 products have at most eight significant bits and are
      // exactly representable in BF16, including the smallest 2^-18 result.
      float expected = product;
#ifndef GEMMINI_MX_BF16_ARITH
      if (std::fabs(product) < 0x1p-16f)
        expected = 0;
#endif
      const float actual = mx::mx_product_quantize_trunc(product, 8, 7);
      if (actual != expected) {
        std::fprintf(stderr, "BF16 product mismatch: %02x * %02x: %a != %a\n", a, b,
                     static_cast<double>(actual), static_cast<double>(expected));
        return 1;
      }
      ++checked;
    }
  }
  const float tiny = 0x1p-18f;
#ifdef GEMMINI_MX_BF16_ARITH
  if (mx::f32_to_bf16_rne(mx::mx_product_quantize_trunc(tiny, 8, 7)) != 0x3680)
    return 2;
#endif
  // Full-BF16 support must not change the reduced-precision product floor.
  if (mx::mx_product_quantize_trunc(tiny, 4, 3) != 0 ||
      mx::mx_product_quantize_trunc(-tiny, 4, 3) != 0)
    return 3;
  std::printf("PASS: %u finite E4M3 product pairs; reduced-precision floor retained\n", checked);
  return 0;
}
