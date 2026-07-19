BUILD_TYPE 			?= Release
BUILD_DIRECTORY 	?= $(if $(filter Release,$(BUILD_TYPE)),build/release,build/debug)
BUILD_DASHBOARD 	?= $(if $(filter Release,$(BUILD_TYPE)),OFF,ON)
BUILD_TESTS			?= $(if $(filter Release,$(BUILD_TYPE)),OFF,ON)
RUN_PARALLEL_TESTS 	?= ON
GENERATOR 			?= Ninja
LINKER 				?= lld
SANITIZER       	?= $(if $(filter Release,$(BUILD_TYPE)),None,General)
CMAKE  				?= cmake
LTO_FLAG			:= $(if $(filter Release,$(BUILD_TYPE)),ON,OFF)

ifeq ($(OS),Windows_NT)
	PLATFORM := Windows
else
	UNAME_S := $(shell uname -s)

	ifeq ($(UNAME_S),Linux)
		PLATFORM := Linux
	else ifeq ($(UNAME_S),Darwin)
		PLATFORM := macOS
	else
		$(error Unsupported platform: $(UNAME_S))
	endif
endif

ifeq ($(PLATFORM),Windows)
	CC					:= cl
	CXX					:= cl
	CACHE_LAUNCHER 		:= sccache
	SCCACHE_DIRECTORY 	?= $(CURDIR)/.sccache
else
	CC 				:= clang
	CXX				:= clang++
	CACHE_LAUNCHER 	:= ccache
endif

ifeq ($(PLATFORM),Windows)
	COMPILER_FLAGS_GLOBAL 	:= -MP -Zf -DNOMINMAX -DWIN32_LEAN_AND_MEAN
	COMPILER_FLAGS_STRICT	:=
	LINKER_FLAGS 			:=

	ifeq ($(BUILD_TYPE),Debug)
		COMPILER_FLAGS_STRICT += -fsanitize=address # MSVC sets sanitizers via compiler flags.
	endif

	ifeq ($(BUILD_TYPE),Release)
		COMPILER_FLAGS_GLOBAL 	+= -GL -O2
		LINKER_FLAGS 			:= -LTCG:incremental -OPT:REF -OPT:ICF
	endif
else
	LINKER_FLAGS 			    := -fuse-ld=$(LINKER)
	COMPILER_FLAGS_GLOBAL 	    :=
	COMPILER_FLAGS_STRICT       :=
	COMPILER_FLAGS_SANITIZERS   :=

	ifeq ($(BUILD_TYPE),Debug)
		COMPILER_FLAGS_STRICT := -Wall -Wextra -Werror -Wconversion -Wsign-conversion -Wshadow \
						         -fstack-protector-strong -Wpadded -Wvla

		ifeq ($(SANITIZER),General)
            COMPILER_FLAGS_SANITIZERS 	:= -fsanitize=address,undefined
        endif
	else
		COMPILER_FLAGS_GLOBAL := -ffile-prefix-map=$(CURDIR)=. -O3
	endif
endif

ifeq ($(RUN_PARALLEL_TESTS),ON)
	RUN_PARALLEL_TESTS := --parallel
else
	RUN_PARALLEL_TESTS :=
endif

.PHONY: configure build test clean help

help:
	@echo "Ballistic Build System"
	@echo "Usage: make [target] [VARIABLE=value]"
	@echo ""
	@echo "Targets:"
	@echo "  configure       Configure CMake project"
	@echo "  configure-all   Configure CMake project for all builds"
	@echo "  build           Build the project"
	@echo "  build-all       Build the project for all builds"
	@echo "  test            Run the test suite via CTest"
	@echo "  clean           Remove build directory"
	@echo ""
	@echo "Variables:"
	@echo "  BUILD_TYPE            	Debug | Release (default: Release)"
	@echo "  BUILD_DASHBOARD		ON | OFF (default: OFF)"
	@echo "  BUILD_TESTS		   	ON | OFF (default: OFF)"
	@echo "  RUN_PARALLEL_TESTS		ON | OFF (default: ON)"
	@echo "  GENERATOR             	Build Generator (default: Ninja)"
	@echo "  LINKER                	Linker override (default: lld)"
	@echo "  SANITIZER             	General | None  (default: None)"
	@echo "  CC / CXX              	Compiler overrides"

BALLISTIC_BUILD_TYPES := Debug Release

define CONFIGURE_ALL_TEMPLATE
.PHONY: configure-all-$(1)
configure-all-$(1):
	@echo "==> Configuring $(1)..."
	@$(MAKE) configure BUILD_TYPE=$(1) --no-print-directory
endef
$(foreach type,$(BALLISTIC_BUILD_TYPES),$(eval $(call CONFIGURE_ALL_TEMPLATE,$(type))))

define BUILD_ALL_TEMPLATE
.PHONY: build-all-$(1)
build-all-$(1):
	@echo "==> Building $(1)..."
	@$(MAKE) build BUILD_TYPE=$(1) BUILD_DIRECTORY=build/$(1) --no-print-directory
endef
$(foreach type,$(BALLISTIC_BUILD_TYPES),$(eval $(call BUILD_ALL_TEMPLATE,$(type))))

define CLEAN_ALL_TEMPLATE
.PHONY: clean-all-$(1)
clean-all-$(1):
	@$(CMAKE) -E remove_directory build-$(1)
endef
$(foreach type,$(BALLISTIC_BUILD_TYPES),$(eval $(call CLEAN_ALL_TEMPLATE,$(type))))

configure:
	$(CMAKE) -G "$(GENERATOR)" -B "$(BUILD_DIRECTORY)" \
		-DCMAKE_EXPORT_COMPILE_COMMANDS=ON \
		-DCMAKE_BUILD_TYPE=$(BUILD_TYPE) \
		-DCMAKE_C_COMPILER=$(CC) \
		-DCMAKE_CXX_COMPILER=$(CXX) \
		-DCMAKE_C_FLAGS="$(COMPILER_FLAGS_GLOBAL)" \
		-DCMAKE_CXX_FLAGS="$(COMPILER_FLAGS_GLOBAL)" \
		-DCMAKE_C_COMPILER_LAUNCHER=$(CACHE_LAUNCHER) \
		-DCMAKE_CXX_COMPILER_LAUNCHER=$(CACHE_LAUNCHER) \
		-DCMAKE_EXE_LINKER_FLAGS="$(LINKER_FLAGS)" \
		-DCMAKE_SHARED_LINKER_FLAGS="$(LINKER_FLAGS)" \
		-DBALLISTIC_BUILD_DASHBOARD="$(BUILD_DASHBOARD)" \
		-DBALLISTIC_BUILD_TESTS="$(BUILD_TESTS)" \
		-DBALLISTIC_STRICT_FLAGS="$(COMPILER_FLAGS_STRICT)" \
		-DBALLISTIC_SANITIZERS="$(COMPILER_FLAGS_SANITIZERS)" \
		-DBALLISTIC_ENABLE_LINK_TIME_OPTIMIZATION=$(LTO_FLAG)

    # Makes it easier for fetch compile_commands.json for CLion.
	-cmake -E create_symlink $(BUILD_DIRECTORY)/compile_commands.json compile_commands.json

build:
	$(CMAKE) --build $(BUILD_DIRECTORY) --config $(BUILD_TYPE) --target all --parallel

test:
	$(CMAKE) -E chdir $(BUILD_DIRECTORY) ctest -C $(BUILD_TYPE) --output-on-failure $(RUN_PARALLEL_TESTS) --verbose

clean:
		$(CMAKE) -E remove_directory $(BUILD_DIRECTORY)

configure-all: $(addprefix configure-all-,$(BALLISTIC_BUILD_TYPES))

build-all: $(addprefix build-all-,$(BALLISTIC_BUILD_TYPES))

clean-all: $(addprefix clean-all-,$(BALLISTIC_BUILD_TYPES))
	@$(CMAKE) -E remove_directory $(BUILD_DIRECTORY)


