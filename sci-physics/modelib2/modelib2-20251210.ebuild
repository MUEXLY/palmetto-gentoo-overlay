# Copyright 1999-2024 Gentoo Authors
# Distributed under the terms of the GNU General Public License v2

EAPI=8

PYTHON_COMPAT=( python3_{10..13} )
DISTUTILS_OPTIONAL=1
#DISTUTILS_USE_PEP517=setuptools
CMAKE_MAKEFILE_GENERATOR=emake

inherit git-r3 cmake

convert_month() {
	local months=( "" Jan Feb Mar Apr May Jun Jul Aug Sep Oct Nov Dec )
	echo ${months[${1#0}]}
}

DESCRIPTION="The Mechanics of Defects Evolution Library 2 (MoDELib2)"
HOMEPAGE="https://github.com/giacomopo/MoDELib2"
EGIT_REPO_URI="https://github.com/giacomopo/MoDELib2.git"


LICENSE="GPL-2"
SLOT="0"
KEYWORDS="**" # live ebuild

# source directory
S="${WORKDIR}/MoDELib2"

IUSE="mpi opencl +openmp +python"

RDEPEND="
    sys-libs/zlib
    mpi? (
        virtual/mpi
        sci-libs/hdf5:=[mpi]
    )
    python? ( ${PYTHON_DEPS} )
    sci-libs/fftw:3.0=
    sci-libs/netcdf:=
    dev-cpp/eigen:3
    dev-libs/boost
    sci-libs/suitesparse
    dev-python/pybind11
"

DEPEND="${RDEPEND}"

REQUIRED_USE="
	python? ( ${PYTHON_REQUIRED_USE} )
"

src_prepare() {
    sed -i 's/add_subdirectory(${CMAKE_CURRENT_SOURCE_DIR}\/DDqt DDqt)/# &/' "${S}/tools/CMakeLists.txt" || die
    cmake_src_prepare
    use python && distutils-r1_src_prepare
}


src_configure() {
	local mycmakeargs=(
		-DCMAKE_INSTALL_SYSCONFDIR="${EPREFIX}/etc"
		-DBUILD_SHARED_LIBS=ON
		-DBUILD_MPI=$(usex mpi)
		-DFFT=FFTW3
		-DPKG_OPENMP=$(usex openmp)
		-DPKG_PYTHON=$(usex python)
		-DPKG_MPIIO=$(usex mpi)
	)

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

	if use python; then
		pushd ../python || die
		distutils-r1_src_install
		popd || die
	fi
}

