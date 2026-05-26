# Copyright 2022 Gentoo Authors
# Distributed under the terms of the GNU General Public License v2

EAPI=8

PYTHON_COMPAT=( python3_{10..14} )
inherit cmake python-any-r1
DOCS_BUILDER="doxygen"
DOCS_DIR="build/docs"
DOCS_CONFIG_NAME="doxygen.cfg"
DOCS_DEPEND="
	media-gfx/graphviz
	virtual/latex-base
	$(python_gen_any_dep '
		dev-python/sphinx[${PYTHON_USEDEP}]
		dev-python/recommonmark[${PYTHON_USEDEP}]
		dev-python/myst-parser[${PYTHON_USEDEP}]
	')
"
inherit docs

# We cannot unbundle this because it has to be compiled with the clang/llvm
# that we are building here. Otherwise we run into problems running the compiler.
#from sycl/llvm/lib/SYCLLowerIR/CMakeLists.txt
VC_INTR_COMMIT="4fc83e12979096db72c129bd432238d5ca397e4d"

# This one can be unbundled I think
UMF_PV="1.1.0"
NIGHTLY_VER="nightly-${PV//./-}"
IFS='.' read -r PV_YEAR PV_MONTH PV_DAY <<< "${PV}"

# From sycl/cmake/modules/FetchEmhash.cmake
EMHASH_COMMIT="5e131ba09a5290823fe71099d9c35eb5df5345b6"

DESCRIPTION="oneAPI Data Parallel C++ compiler"
HOMEPAGE="https://github.com/intel/llvm"
SRC_URI="
	https://github.com/intel/llvm/archive/refs/tags/${NIGHTLY_VER}.tar.gz -> ${P}.tar.gz
	https://github.com/intel/vc-intrinsics/archive/${VC_INTR_COMMIT}.tar.gz -> ${P}-vc-intrinsics-${VC_INTR_COMMIT}.tar.gz
	https://github.com/ktprime/emhash/archive/${EMHASH_COMMIT}.tar.gz -> ${P}-emhash-${EMHASH_COMMIT}.tar.gz
	https://github.com/oneapi-src/unified-memory-framework/archive/refs/tags/v${UMF_PV}.tar.gz -> ${P}-unified-memory-framework-${UMF_PV}.tar.gz
"
S="${WORKDIR}/llvm-${NIGHTLY_VER}"
CMAKE_USE_DIR="${S}/llvm"
BUILD_DIR="${S}/build"

LICENSE="Apache-2.0 MIT"
SLOT="0/6" # Based on libsycl.so
KEYWORDS="~amd64"

ALL_LLVM_TARGETS=( AArch64 AMDGPU ARM AVR BPF Hexagon Lanai Mips MSP430
	NVPTX PowerPC RISCV Sparc SystemZ WebAssembly X86 XCore )
ALL_LLVM_TARGETS=( "${ALL_LLVM_TARGETS[@]/#/llvm_targets_}" )
LLVM_TARGET_USEDEPS=${ALL_LLVM_TARGETS[@]/%/(-)?}

IUSE="cuda hip test ${ALL_LLVM_TARGETS[*]}"
REQUIRED_USE="
	?? ( cuda hip )
	cuda? ( llvm_targets_NVPTX )
	hip? ( llvm_targets_AMDGPU )
"
RESTRICT="!test? ( test )"

BDEPEND="virtual/pkgconfig"

DEPEND="
	dev-libs/boost:=
	dev-libs/level-zero:=
	dev-libs/opencl-icd-loader
	>=dev-util/opencl-headers-2025.06.13
	dev-util/spirv-headers
	dev-util/spirv-tools
	media-libs/libva
	dev-build/libtool
	>=dev-cpp/parallel-hashmap-1.3.12
	cuda? ( dev-util/nvidia-cuda-toolkit:= )
	hip? ( dev-util/hip:= )
"
RDEPEND="${DEPEND}"

PATCHES=(
	"${FILESDIR}/DPC++-6.3.0-zstd.patch"
)

src_configure() {
	# Extracted from buildbot/configure.py
	local mycmakeargs=(
		-DLLVM_ENABLE_ASSERTIONS=ON
		-DLLVM_TARGETS_TO_BUILD="${LLVM_TARGETS// /;}"
		-DLLVM_EXTERNAL_PROJECTS="opencl;sycl-jit;sycl;unified-runtime;llvm-spirv;libdevice;xpti;xptifw"
		-DLLVM_EXTERNAL_SYCL_SOURCE_DIR="${S}/sycl"
		-DLLVM_EXTERNAL_LLVM_SPIRV_SOURCE_DIR="${S}/llvm-spirv"
		-DLLVM_EXTERNAL_XPTI_SOURCE_DIR="${S}/xpti"
		-DXPTI_SOURCE_DIR="${S}/xpti"
		-DLLVM_EXTERNAL_XPTIFW_SOURCE_DIR="${S}/xptifw"
		-DLLVM_EXTERNAL_LIBDEVICE_SOURCE_DIR="${S}/libdevice"
		-DLLVM_ENABLE_PROJECTS="clang;sycl-jit;sycl;llvm-spirv;opencl;libdevice;xpti;xptifw"
		-DLLVM_BUILD_TOOLS=ON
		-DSYCL_ENABLE_WERROR=OFF
		-DSYCL_INCLUDE_TESTS="$(usex test)"
		-DCLANG_INCLUDE_TESTS="$(usex test)"
		-DLLVM_INCLUDE_TESTS="$(usex test)"
		-DLLVM_SPIRV_INCLUDE_TESTS="$(usex test)"
		-DLLVM_ENABLE_DOXYGEN="$(usex doc)"
		-DLLVM_ENABLE_SPHINX="$(usex doc)"
		-DLLVM_USE_SPLIT_DWARF=OFF
		-DLLVM_BUILD_DOCS="$(usex doc)"
		-DSYCL_ENABLE_XPTI_TRACING=ON
		-DLLVM_ENABLE_LLD=OFF
		-DXPTI_ENABLE_WERROR=OFF
		-DSYCL_ENABLE_BACKENDS="level_zero;opencl;$(usev hip);$(usev cuda)"
		-DLLVM_EXTERNAL_SPIRV_HEADERS_SOURCE_DIR="${ESYSROOT}/usr"
		-DFETCHCONTENT_SOURCE_DIR_VC-INTRINSICS="${WORKDIR}/vc-intrinsics-${VC_INTR_COMMIT}"
		-DFETCHCONTENT_SOURCE_DIR_EMHASH="${WORKDIR}/emhash-${EMHASH_COMMIT}"
		-DFETCHCONTENT_SOURCE_DIR_UNIFIED-MEMORY-FRAMEWORK="${WORKDIR}/unified-memory-framework-${UMF_PV}"
		-DSYCL_COMPILER_VERSION="${PV}"
		-DDPCPP_VERSION_MAJOR="${PV_YEAR}"
		-DDPCPP_VERSION_MINOR="${PV_MONTH}"
		-DDPCPP_VERSION_PATCH="${PV_DAY}"
		# The sycl part of the build system insists on installing during compiling
		# Install it to some temporary directory
		-DCMAKE_INSTALL_PREFIX="${BUILD_DIR}/install"
		-DCMAKE_INSTALL_MANDIR="${BUILD_DIR}/install/share/man"
		-DCMAKE_INSTALL_INFODIR="${BUILD_DIR}/install/share/info"
		-DCMAKE_INSTALL_DOCDIR="${BUILD_DIR}/install/share/doc/${PF}"
	)

	if use hip; then
		mycmakeargs+=(
			-DSYCL_BUILD_PI_HIP_PLATFORM=AMD
			-DLIBCLC_GENERATE_REMANGLED_VARIANTS=ON
			-DLIBCLC_TARGETS_TO_BUILD=";amdgcn--;amdgcn--amdhsa"
		)
	fi

	if use cuda; then
		mycmakeargs+=(
			-DLIBCLC_GENERATE_REMANGLED_VARIANTS=ON
			-DLIBCLC_TARGETS_TO_BUILD=";nvptx64--;nvptx64--nvidiacl"
		)
	fi

	if use doc; then
		mycmakeargs+=( -DSPHINX_WARNINGS_AS_ERRORS=OFF )
	fi

	cmake_src_configure
}

src_compile() {
	# Build sycl (this also installs some stuff already)
	cmake_build deploy-sycl-toolchain

	use doc && cmake_build doxygen-sycl

	# Install all other files into the same temporary directory
	cmake_build install
}

src_test() {
	cmake_build check
}

src_install() {
	einstalldocs

	local LLVM_INTEL_DIR="/usr/lib/llvm/intel"
	dodir "${LLVM_INTEL_DIR}"

	# Copy our temporary directory to the image directory
	mv "${BUILD_DIR}/install"/* "${ED}/${LLVM_INTEL_DIR}" || die

	# Convienence symlinks
	dosym "${LLVM_INTEL_DIR}/bin/clang" "/usr/bin/icx"
	dosym "${LLVM_INTEL_DIR}/bin/clang++" "/usr/bin/icpx"

	# Copied from llvm ebuild, put env file last so we don't overwrite main llvm/clang
	newenvd - "60llvm-intel" <<-_EOF_
		PATH="${EPREFIX}${LLVM_INTEL_DIR}/bin"
		# we need to duplicate it in ROOTPATH for Portage to respect...
		ROOTPATH="${EPREFIX}${LLVM_INTEL_DIR}/bin"
		MANPATH="${EPREFIX}${LLVM_INTEL_DIR}/share/man"
		LDPATH="${EPREFIX}${LLVM_INTEL_DIR}/lib:${EPREFIX}${LLVM_INTEL_DIR}/lib64"
	_EOF_
}
