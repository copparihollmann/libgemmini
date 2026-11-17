BUILD_GOALS := $(if $(MAKECMDGOALS),$(MAKECMDGOALS),default)
ifneq ($(strip $(filter-out check-mx-products clean,$(BUILD_GOALS))),)
ifndef RISCV
$(error RISCV is unset)
else
$(info Running with RISCV=$(RISCV))
endif
endif

PREFIX ?= $RISCV/

BF16_LIBS = libgemmini_bf16_dim8.so libgemmini_bf16_dim16.so libgemmini_bf16_dim32.so
MXBF16_LIBS = libgemmini_mxbf16_dim16.so libgemmini_mxbf16_dim32.so
MODEL_HEADERS = gemmini.h mx_fp_math.h $(wildcard perf/*.h perf/*/*.h)

default: libgemmini.so libgemmini_dim32.so libgemmini_dim8.so libgemmini_dim32q.so libgemmini_dim4.so $(BF16_LIBS) $(MXBF16_LIBS)

libgemmini.so libgemmini_dim32.so libgemmini_dim8.so libgemmini_dim32q.so libgemmini_dim4.so $(BF16_LIBS) $(MXBF16_LIBS): $(MODEL_HEADERS)

libgemmini.so: gemmini.cc gemmini_perf.cc $(wildcard perf/*.cc perf/*/*.cc)
	g++ -L $(RISCV)/lib -Wl,-rpath,$(RISCV)/lib -shared -o $@ -std=c++17 -I $(RISCV)/include -fPIC -O3 $(filter %.cc,$^)

# DIM=32 mesh model, registered as extension "gemmini_dim32" (run: spike --extension=gemmini_dim32 ...)
libgemmini_dim32.so: gemmini.cc gemmini_perf.cc $(wildcard perf/*.cc perf/*/*.cc)
	g++ -DGEMMINI_DIM=32 -L $(RISCV)/lib -Wl,-rpath,$(RISCV)/lib -shared -o $@ -std=c++17 -I $(RISCV)/include -fPIC -O3 $(filter %.cc,$^)

# DIM=32 native E4M3 quad (64-B spad rows, branch large-mesh-fp8), extension "gemmini_dim32q"
libgemmini_dim32q.so: gemmini.cc gemmini_perf.cc $(wildcard perf/*.cc perf/*/*.cc)
	g++ -DGEMMINI_DIM=32 -DGEMMINI_E4M3_NATIVE_QUAD -L $(RISCV)/lib -Wl,-rpath,$(RISCV)/lib -shared -o $@ -std=c++17 -I $(RISCV)/include -fPIC -O3 $(filter %.cc,$^)

# DIM=4 mesh model (all-bf16 acc, 128 KB spad), extension "gemmini_dim4"
libgemmini_dim4.so: gemmini.cc gemmini_perf.cc $(wildcard perf/*.cc perf/*/*.cc)
	g++ -DGEMMINI_DIM=4 -L $(RISCV)/lib -Wl,-rpath,$(RISCV)/lib -shared -o $@ -std=c++17 -I $(RISCV)/include -fPIC -O3 $(filter %.cc,$^)

# DIM=8 mesh model (all-bf16 acc), registered as extension "gemmini_dim8" (run: spike --extension=gemmini_dim8 ...)
libgemmini_dim8.so: gemmini.cc gemmini_perf.cc $(wildcard perf/*.cc perf/*/*.cc)
	g++ -DGEMMINI_DIM=8 -L $(RISCV)/lib -Wl,-rpath,$(RISCV)/lib -shared -o $@ -std=c++17 -I $(RISCV)/include -fPIC -O3 $(filter %.cc,$^)

# Plain BF16 Gemmini (BF16Dim*BaselineConfig), registered as "gemmini_bf16_dim<N>"
# (run: spike --extension=gemmini_bf16_dim16 ...)
libgemmini_bf16_dim%.so: gemmini.cc gemmini_perf.cc $(wildcard perf/*.cc perf/*/*.cc)
	g++ -DGEMMINI_BF16 -DGEMMINI_DIM=$* -L $(RISCV)/lib -Wl,-rpath,$(RISCV)/lib -shared -o $@ -std=c++17 -I $(RISCV)/include -fPIC -O3 $(filter %.cc,$^)

# MX mesh with full BF16 PE arithmetic (MxE4M3LutBf16Dim*GemminiBoomConfig), extension "gemmini_mxbf16_dim<N>"
libgemmini_mxbf16_dim%.so: gemmini.cc gemmini_perf.cc $(wildcard perf/*.cc perf/*/*.cc)
	g++ -DGEMMINI_MX_BF16_ARITH -DGEMMINI_DIM=$* -L $(RISCV)/lib -Wl,-rpath,$(RISCV)/lib -shared -o $@ -std=c++17 -I $(RISCV)/include -fPIC -O3 $(filter %.cc,$^)

.PHONY: install
install: libgemmini.so libgemmini_dim32.so libgemmini_dim8.so $(BF16_LIBS) $(MXBF16_LIBS)
	cp libgemmini.so libgemmini_dim32.so libgemmini_dim8.so $(BF16_LIBS) $(MXBF16_LIBS) $(RISCV)/lib

clean:
	rm -rf *.o *.so

.PHONY: check-mx-products
check-mx-products:
	python3 tests/run_mx_products.py --cxx "$(CXX)"
