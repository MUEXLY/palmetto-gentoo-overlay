# Copyright 2022 Gentoo Authors
# Distributed under the terms of the GNU General Public License v2

EAPI=8

# Missing deps for documentation
# PYTHON_COMPAT=( python3_{10..11} )
# DOCS_BUILDER="sphinx"
# DOCS_DIR="documentation/library_guide"
# DOCS_AUTODOC=0
inherit cmake #python-any-r1 docs

DESCRIPTION="oneAPI Data Parallel C++ Library"
HOMEPAGE="https://github.com/oneapi-src/oneDPL"
SRC_URI="https://github.com/oneapi-src/oneDPL/archive/refs/tags/${PN}-release-${PV}.tar.gz"
S="${WORKDIR}/${PN}-${PN}-release-${PV}"

LICENSE="Apache-2.0-with-LLVM-exceptions"
SLOT="0"
KEYWORDS="~amd64"

IUSE=""
#TODO: Figure out how to use the test
RESTRICT="test"

BDEPEND="virtual/pkgconfig"

DEPEND="
	sys-devel/DPC++:0/6
	dev-libs/level-zero
	dev-cpp/tbb
"
RDEPEND="${DEPEND}"

src_prepare() {
	# Not using the DPC++ compiler doesn't really make sense here
	export CXX="icpx"
	export CC="icx"
	cmake_src_prepare
}

src_configure() {
	local mycmakeargs=(
		-DONEDPL_BACKEND="dpcpp"
	)

	cmake_src_configure
}

src_compile() {
	cmake_src_compile
	cmake -DSKIP_HEADERS_SUBDIR=ON -P cmake/scripts/generate_config.cmake || die
	# docs_compile
}

src_install() {
	einstalldocs
	doheader -r "${S}/include/oneapi"
	insinto "/usr/$(get_libdir)/cmake/oneDPL/"
	doins output/*.cmake
	insinto "/usr/$(get_libdir)/pkgconfig/"
	doins output/*.pc
}
