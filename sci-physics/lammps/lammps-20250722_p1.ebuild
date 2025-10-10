# Copyright 1999-2024 Gentoo Authors
# Distributed under the terms of the GNU General Public License v2

EAPI=8

PYTHON_COMPAT=( python3_{10..13} )
DISTUTILS_OPTIONAL=1
DISTUTILS_USE_PEP517=setuptools
CMAKE_MAKEFILE_GENERATOR=emake
# Doc building insists on fetching mathjax
# DOCS_BUILDER="doxygen"
# DOCS_DEPEND="
# 	media-gfx/graphviz
# 	dev-libs/mathjax
# "

inherit cmake fortran-2 distutils-r1 # docs

convert_month() {
	local months=( "" Jan Feb Mar Apr May Jun Jul Aug Sep Oct Nov Dec )
	echo ${months[${1#0}]}
}

MY_RELTYPE="stable"

MY_PV="$((10#${PV:6:2}))$(convert_month ${PV:4:2})${PV:0:4}${PV:8}"
MY_PV="${MY_PV/_p/_update}"
MY_P="${PN}-${MY_RELTYPE}_${MY_PV}"
TABGAP_COMMIT_ID="6e04418f7ca5ad17c12aeaeb05c0f2b1517a341b"

DESCRIPTION="Large-scale Atomic/Molecular Massively Parallel Simulator"
HOMEPAGE="https://www.lammps.org"
SRC_URI="
	https://github.com/lammps/lammps/archive/refs/tags/${MY_RELTYPE}_${MY_PV}.tar.gz
	test? (
		https://github.com/google/googletest/archive/release-1.12.1.tar.gz -> ${PN}-gtest-1.12.1.tar.gz
	)
	tabgap? (
		https://gitlab.com/jezper/tabgap/-/archive/${TABGAP_COMMIT_ID}/tabgap-${TABGAP_COMMIT_ID}.tar.gz -> tabgap.tar.gz
	)
"
S="${WORKDIR}/${MY_P}/cmake"

LICENSE="GPL-2"
SLOT="0"
if [[ ${MY_RELTYPE} == patch ]]; then
    KEYWORDS="~amd64 ~x86"
elif [[ ${MY_RELTYPE} == stable ]]; then
    KEYWORDS="amd64 x86"
else
    KEYWORDS=""
fi
IUSE="cuda examples +extra gzip hip lammps-memalign mpi opencl +openmp +python test oneapi tabgap"

# Based on https://docs.lammps.org/Build_extras.html#kokkos
KOKKOS_IUSE_HOST="
	native
	amdavx
	armv80
	armv81
	armv8_thunderx
	armv8_thunderx2
	a64fx
	armv9_grace
	snb
	hsw
	bdw
	icl
	icx
	skl
	skx
	knc
	knl
	spr
	power8
	power9
	zen
	zen2
	zen3
	zen4
	zen5
	riscv_sg2042
	riscv_rva22v
"

KOKKOS_IUSE_GPU_NVIDIA="
	kepler30
	kepler32
	kepler35
	kepler37
	maxwell50
	maxwell52
	maxwell53
	pascal60
	pascal61
	volta70
	volta72
	turing75
	ampere80
	ampere86
	ada89
	hopper90
	blackwell100
	blackwell120
"
KOKKOS_IUSE_GPU_AMD="
	amd_gfx906
	amd_gfx908
	amd_gfx90a
	amd_gfx940
	amd_gfx942
	amd_gfx942_apu
	amd_gfx1030
	amd_gfx1100
	amd_gfx1103
"

KOKKOS_IUSE_GPU_INTEL="
	intel_gen
	intel_dg1
	intel_gen9
	intel_gen11
	intel_gen12lp
	intel_xehp
	intel_pvc
	intel_dg2
"

KOKKOS_IUSE_HOST_EXPANDED=$(printf " kokkos_host_%s" ${KOKKOS_IUSE_HOST})
KOKKOS_IUSE_GPU_NVIDIA_EXPANDED=$(printf " kokkos_gpu_%s" ${KOKKOS_IUSE_GPU_NVIDIA})
KOKKOS_IUSE_GPU_AMD_EXPANDED=$(printf " kokkos_gpu_%s" ${KOKKOS_IUSE_GPU_AMD})
KOKKOS_IUSE_GPU_INTEL_EXPANDED=$(printf " kokkos_gpu_%s" ${KOKKOS_IUSE_GPU_INTEL})
IUSE+=" ${KOKKOS_IUSE_HOST_EXPANDED} ${KOKKOS_IUSE_GPU_NVIDIA_EXPANDED} ${KOKKOS_IUSE_GPU_AMD_EXPANDED} ${KOKKOS_IUSE_GPU_INTEL_EXPANDED} "


# Requires write access to /dev/dri/renderD...
RESTRICT="test"

RDEPEND="
	app-arch/gzip
	media-libs/libpng:0
	sys-libs/zlib
	mpi? (
		virtual/mpi
		sci-libs/hdf5:=[mpi]
	)
	python? ( ${PYTHON_DEPS} )
	sci-libs/voro++
	virtual/blas
	virtual/lapack
	sci-libs/fftw:3.0=
	sci-libs/netcdf:=
	cuda? (
		>=dev-util/nvidia-cuda-toolkit-4.2.9-r1:=
		x11-drivers/nvidia-drivers
	)
	opencl? ( virtual/opencl )
	hip? (
		dev-util/hip:=
		sci-libs/hipCUB:=
	)
	oneapi? ( dev-libs/intel-compute-runtime:=[l0] )
	dev-cpp/eigen:3
	"
	# Kokkos-3.5 not in tree atm
	# kokkos? ( dev-cpp/kokkos-3.5.* )
BDEPEND="${DISTUTILS_DEPS}"
DEPEND="${RDEPEND}
	test? (
		dev-cpp/gtest
		dev-libs/libyaml
	)
"

REQUIRED_USE="
	python? ( ${PYTHON_REQUIRED_USE} )
	?? ( cuda opencl hip oneapi )
	?? ( ${KOKKOS_IUSE_HOST_EXPANDED} )
	?? ( ${KOKKOS_IUSE_GPU_NVIDIA_EXPANDED} ${KOKKOS_IUSE_GPU_AMD_EXPANDED} ${KOKKOS_IUSE_GPU_INTEL_EXPANDED} )
"

# NVIDIA: require cuda OR hip
for gpu in ${KOKKOS_IUSE_GPU_NVIDIA}; do
	REQUIRED_USE+=" kokkos_gpu_${gpu}? ( || ( cuda hip ) )"
done

# AMD: require hip
for gpu in ${KOKKOS_IUSE_GPU_AMD}; do
	REQUIRED_USE+=" kokkos_gpu_${gpu}? ( hip )"
done

# Intel: require oneapi
# In reality it requires sycl but there is no virtual/sycl yet
for gpu in ${KOKKOS_IUSE_GPU_INTEL}; do
	REQUIRED_USE+=" kokkos_gpu_${gpu}? ( oneapi )"
done

src_prepare() {
	sed -i '/set(CMAKE_TUNE_DEFAULT.*-Xcudafe/s/^/# /' "${WORKDIR}/${MY_P}/cmake/CMakeLists.txt" || die
	cmake_src_prepare
	if use python; then
		pushd ../python || die
		distutils-r1_src_prepare
		popd || die
	fi
	if use test; then
		mkdir "${BUILD_DIR}/_deps"
		cp "${DISTDIR}/${PN}-gtest-1.12.1.tar.gz" "${BUILD_DIR}/_deps/release-1.12.1.tar.gz"
	fi
	if use tabgap; then
		cp -a  "${WORKDIR}/tabgap-${TABGAP_COMMIT_ID}/lammps/." "${WORKDIR}/${MY_P}/src" || die
	fi
}

src_configure() {
	local mycmakeargs=(
		-DCMAKE_INSTALL_SYSCONFDIR="${EPREFIX}/etc"
		-DBUILD_SHARED_LIBS=ON
		-DBUILD_MPI=$(usex mpi)
		-DBUILD_DOC=OFF
		#-DBUILD_DOC=$(usex doc)
		-DENABLE_TESTING=$(usex test)
		-DPKG_ASPHERE=ON
		-DPKG_BODY=ON
		-DPKG_CLASS2=ON
		-DPKG_COLLOID=ON
		-DPKG_COMPRESS=ON
		-DPKG_CORESHELL=ON
		-DPKG_DIPOLE=ON
		-DPKG_EXTRA-COMPUTE=$(usex extra)
		-DPKG_EXTRA-DUMP=$(usex extra)
		-DPKG_EXTRA-FIX=$(usex extra)
		-DPKG_EXTRA-MOLECULE=$(usex extra)
		-DPKG_EXTRA-PAIR=$(usex extra)
		-DPKG_GRANULAR=ON
		-DPKG_KSPACE=ON
		-DFFT=FFTW3
		#-DPKG_KOKKOS=OFF
		-DPKG_KOKKOS=ON
		-DKokkos_ENABLE_OPENMP=$(usex openmp)
		-DKokkos_ENABLE_CUDA=$(usex cuda)
		-DKokkos_ENABLE_SYCL=$(usex oneapi)
		-DKokkos_ENABLE_HIP=$(usex hip)
		-DKokkos_ENABLE_HWLOC=ON
		#-DPKG_KOKKOS=$(usex kokkos)
		#$(use kokkos && echo -DEXTERNAL_KOKKOS=ON)
		-DPKG_MANYBODY=ON
		-DPKG_MC=ON
		-DPKG_MEAM=ON
		-DPKG_MISC=ON
		-DPKG_MOLECULE=ON
		-DPKG_OPENMP=$(usex openmp)
		-DPKG_PERI=ON
		-DPKG_QEQ=ON
		-DPKG_REPLICA=ON
		-DPKG_RIGID=ON
		-DPKG_SHOCK=ON
		-DPKG_SRD=ON
		-DPKG_PYTHON=$(usex python)
		-DPKG_MPIIO=$(usex mpi)
		-DPKG_VORONOI=ON
	)
	if use cuda || use opencl || use hip; then
		mycmakeargs+=( -DPKG_GPU=ON )
		use cuda && mycmakeargs+=( -DGPU_API=cuda )
		use opencl && mycmakeargs+=( -DGPU_API=opencl -DUSE_STATIC_OPENCL_LOADER=OFF )
		use hip && mycmakeargs+=( -DGPU_API=hip -DHIP_PATH="${EPREFIX}/usr" )
	else
		mycmakeargs+=( -DPKG_GPU=OFF )
	fi

	# Helper to uppercase arch string
	_kokkos_flag() {
		echo "${1}" | tr '[:lower:]' '[:upper:]'
	}

	# Hosts
	for arch in ${KOKKOS_IUSE_HOST}; do
		mycmakeargs+=( -DKokkos_ARCH_$(_kokkos_flag ${arch})=$(usex kokkos_host_${arch}) )
	done
	for gpu in ${KOKKOS_IUSE_GPU_NVIDIA} ${KOKKOS_IUSE_GPU_AMD} ${KOKKOS_IUSE_GPU_INTEL}; do
		mycmakeargs+=( -DKokkos_ARCH_$(_kokkos_flag ${gpu})=$(usex kokkos_gpu_${gpu}) )
	done

	cmake_src_configure
	if use python; then
		pushd ../python || die
		distutils-r1_src_configure
		popd || die
	fi
}

src_compile() {
	cmake_src_compile
	if use python; then
		pushd ../python || die
		distutils-r1_src_compile
		popd || die
	fi
}

src_test() {
	cmake_src_test
	if use python; then
		pushd ../python || die
		distutils-r1_src_test
		popd || die
	fi
}

src_install() {
	cmake_src_install

	if use opencl; then
		dobin "${BUILD_DIR}/ocl_get_devices"
	fi

	if use python; then
		pushd ../python || die
		distutils-r1_src_install
		popd || die
	fi

	if use examples; then
		for d in examples bench; do
			local LAMMPS_EXAMPLES="/usr/share/${PN}/${d}"
			insinto "${LAMMPS_EXAMPLES}"
			doins -r "${S}"/../${d}/*
		done
	fi
}

