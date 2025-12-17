# Copyright 1999-2024 Gentoo Authors
# Distributed under the terms of the GNU General Public License v2

EAPI=8

PYTHON_COMPAT=( python3_{10..14} )
DISTUTILS_OPTIONAL=1
CMAKE_MAKEFILE_GENERATOR=emake

inherit git-r3 cmake

DESCRIPTION="The Mechanics of Defects Evolution Library 2 (MoDELib2)"
HOMEPAGE="https://github.com/giacomopo/MoDELib2"
EGIT_REPO_URI="https://github.com/hlclemson/MoDELib2"
EGIT_BRANCH="noise_update_rotation"

LICENSE="GPL-2"
SLOT="0"
KEYWORDS="**" # live ebuild

# source directory
#S="${WORKDIR}/${P}"

IUSE="opencl +openmp +python"

RDEPEND="
    sci-libs/fftw
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
}

src_configure() {
    local mycmakeargs=(
        -DCMAKE_C_COMPILER="${CC}"
        -DCMAKE_CXX_COMPILER="${CXX}"
        -DCMAKE_INSTALL_SYSCONFDIR="${EPREFIX}/etc"
        -DBUILD_SHARED_LIBS=ON
        -DFFT=FFTW3
        -DPKG_OPENMP=$(usex openmp)
        -DPKG_PYTHON=$(usex python)
    )
	cmake_src_configure
}

src_compile() {
	cmake_src_compile
}

src_install() {
    # shared library → usr/lib64 (or lib on x86)
    insinto /usr/$(get_libdir)
    doins "${BUILD_DIR}"/libMoDELib.so

    # executables → usr/bin
    dobin "${BUILD_DIR}"/tools/DDomp/DDomp
    dobin "${BUILD_DIR}"/tools/MicrostructureGenerator/microstructureGenerator
}

