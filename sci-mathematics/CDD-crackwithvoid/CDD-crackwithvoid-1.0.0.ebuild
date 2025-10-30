# Copyright 1999-2022 Gentoo Authors
# Distributed under the terms of the GNU General Public License v2


# Steps:
# 0) Load env: module load intel/19.1.3.304 impi/2019.9.304 intel-mkl/2019.9.304
#
# 1) wget https://web.cels.anl.gov/projects/petsc/download/release-snapshots/petsc-{VERSION}.tar.gz
# ex: https://web.cels.anl.gov/projects/petsc/download/release-snapshots/petsc-3.21.4.tar.gz
#
# extract: tar -xzvf petsc-3.21.4.tar.gz
#
# 2) configure:
# ./configure PETSC_ARCH=intel-opt --with-cc=mpiicc --with-cxx=mpiicpc --with-fc=mpiifort --with-debuggin=0 COPTFLAGS='-O2' FOPTFLAGS='-O2' CXXOPTFLAGS='-O2' --with-blaslapack-dir=$MKLROOT --download-metis --download-parmetis
#
# make PETSC_DIR=/home/mazumder/Void_Nucleation_Code/petsc-3.18.1 PETSC_ARCH=intel-opt all
#
# make PETSC_DIR=/home/mazumder/Void_Nucleation_Code/petsc-3.18.1 PETSC_ARCH=intel-opt check
#
# 3) export:
# export PETSC_DIR=/home/mazumder/Void_Nucleation_Code/petsc-3.18.1 PETSC_ARCH=intel-opt
#
# export LD_LIBRARY_PATH=$PETSC_DIR/$PETSC_ARCH/lib:$LD_LIBRARY_PATH
#
# 4) go to CDD/build
# make clean
# make
#
# 5) test code
# cd ../../TestRun56
# vim config
# vim run.batch
# mpiexec -np 10 ../crack_with_void/build/CDD 10 > log.txt


EAPI=8

# do not pull from remote source
RESTRICT="fetch"

inherit autotools toolchain-funcs

DESCRIPTION="This version of CDD includes the implementation of the void generation by vacancy field. The simulation also includes crack."
HOMEPAGE=""
DISTDIR="/home/hyunsol/gentoo/etc/portage/distfiles"
SRC_URI="/home/hyunsol/gentoo/etc/portage/distfiles/crack_with_void.tar.xz"
S="${WORKDIR}/CDD"

pkg_pretend() {
    [[ -f ${DISTDIR}/crack_with_void.tar.xz ]] || \
        die "Place crack_with_void.tar.xz in ${DISTDIR} (RESTRICT=fetch)"
}

LICENSE="MIT"
SLOT="0"
KEYWORDS="~amd64 ~x86"
IUSE=""

RDEPEND="
sci-libs/fftw:3.0
virtual/cblas
virtual/lapack
sci-libs/umfpack
sci-libs/arpack
sci-libs/hdf5[cxx]
sci-mathematics/petsc
virtual/mpi
"

DEPEND="${RDEPEND}"
BDEPEND="virtual/pkgconfig"

src_prepare() {
  default

  #eautoreconf
}

src_configure() {
  local myconf

  # mpi
  myconf="${myconf} --with-mpi=/usr/bin/mpi"

  # Hardcoded /usr/include in config file break prefixes
  sed -i "s|/usr/include|${EPREFIX}/usr/include|g" configure || die

  myconf="${myconf} --with-petsc=${EPREFIX}/usr/$(get_libdir)/petscdir/lib/petsc/conf/petscvariables"

  econf \
    --disable-download \
    --disable-optim \
    --enable-generic \
    --with-blas="$($(tc-getPKG_CONFIG) --libs blas)" \
    --with-lapack="$($(tc-getPKG_CONFIG) --libs lapack)" \
    ${myconf}
  }

src_test() {
  # This may depend on the used MPI implementation. It is needed
  # with mpich2, but should not be needed with lam-mpi or mpich
  # (if the system is configured correctly).
  ewarn "Please check that your MPI root ring is on before running"
  ewarn "the test phase. Failing to start it before that phase may"
  ewarn "result in a failing emerge."
  epause

  emake -j1 check
}

src_install() {
  default
}
