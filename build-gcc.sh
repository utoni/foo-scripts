#! /bin/bash

set -e
set -x


#working combination
#GCC_VERSION="5.2.0"
#BINUTILS_VERSION="2.27"
#or
#GCC_VERSION="4.4.2"
#BINUTILS_VERSION="2.25"

BIN_DLSITE="https://ftp.gnu.org/gnu/binutils"
GCC_DLSITE="https://mirrors-usa.go-parts.com/gcc/releases"

if [ -d binutils-build ]; then
	ANSW=$(whiptail --clear --menu 'binutils-build exists: delete?' 15 35 5 y yes n no 3>&1 1>&2 2>&3)
	if [ x"${ANSW}" = x'y' ]; then
		rm -rf binutils-build
	fi
fi
if [ -d gcc-build ]; then
        ANSW=$(whiptail --clear --menu 'gcc-build exists: delete?' 15 35 5 y yes n no 3>&1 1>&2 2>&3)
	if [ x"${ANSW}" = x'y' ]; then
		rm -rf gcc-build
	fi
fi

# download choosen binutils version
BIN_CONTENT=$(wget "${BIN_DLSITE}" -q -O - | grep -oE '>binutils-[[:digit:]]+.[[:digit:]]+(|.[[:digit:]]+)(|.[[:digit:]]+).tar.gz<')
BIN_MENU=$(echo "${BIN_CONTENT}" | sed -n 's/^>binutils-\(.*\).tar.gz<$/\1 binutils-\1/p')
BINUTILS_VERSION=$(whiptail --menu 'choose binutils version' 35 55 25 ${BIN_MENU} 3>&1 1>&2 2>&3)
echo "binutils: ${BINUTILS_VERSION}"

# download choosen gcc version
GCC_CONTENT=$(wget "${GCC_DLSITE}" -q -O - | grep -oE '"gcc-[[:digit:]]+.[[:digit:]]+(|.[[:digit:]]+)/"')
GCC_MENU=$(echo "${GCC_CONTENT}" | sed -n 's/^"gcc-\(.*\)\/"$/\1 gcc-\1/p')
GCC_VERSION=$(whiptail --menu 'choose gcc version' 35 55 25 ${GCC_MENU} 3>&1 1>&2 2>&3)
echo "gcc: ${GCC_VERSION}"

# "sysroot"
INSTALLDIR="$(pwd)/gcc-${GCC_VERSION}-root"
if [ -d "${INSTALLDIR}" ]; then
	ANSW=$(whiptail --menu 'sysroot gcc-'"${GCC_VERSION}"'-root exists: delete?' 15 35 5 y yes n no 3>&1 1>&2 2>&3)
	if [ x"${ANSW}" = x'y' ]; then
		rm -rf "${INSTALLDIR}"
	fi
fi

# get the source code
if [ ! -f "binutils-${BINUTILS_VERSION}.tar.gz" ]; then
	wget -O "binutils-${BINUTILS_VERSION}.tar.gz" http://ftp.gnu.org/gnu/binutils/binutils-${BINUTILS_VERSION}.tar.gz
fi
test -d binutils-build || tar -xvf binutils-${BINUTILS_VERSION}.tar.gz
if [ ! -f "gcc-${GCC_VERSION}.tar.bz2" ]; then
	wget -O "gcc-${GCC_VERSION}.tar.bz2" http://www.netgull.com/gcc/releases/gcc-${GCC_VERSION}/gcc-${GCC_VERSION}.tar.bz2
fi
test -d gcc-build || tar -xvf gcc-${GCC_VERSION}.tar.bz2

# download the prerequisites e.g. GMP,MPFR,MPC
cd gcc-${GCC_VERSION}
if [ -x ./contrib/download_prerequisites ]; then
	./contrib/download_prerequisites
else
	# c&p from gcc5 `download_prerequisites` script
	# Necessary to build GCC.
	MPFR=mpfr-2.4.2
	GMP=gmp-4.3.2
	MPC=mpc-0.8.1
	if [ ! -f "$MPFR.tar.bz2" -o ! -h mpfr ]; then
		rm -rf mpfr
		wget ftp://gcc.gnu.org/pub/gcc/infrastructure/$MPFR.tar.bz2
		tar xjf $MPFR.tar.bz2
		ln -sf $MPFR mpfr
	fi
	if [ ! -f "$GMP.tar.bz2" -o ! -h gmp ]; then
		rm -rf gmp
		wget ftp://gcc.gnu.org/pub/gcc/infrastructure/$GMP.tar.bz2
		tar xjf $GMP.tar.bz2
		ln -sf $GMP gmp
	fi
	if [ ! -f "$MPC.tar.gz" -o ! -h mpc ]; then
		rm -rf mpc
		wget ftp://gcc.gnu.org/pub/gcc/infrastructure/$MPC.tar.gz
		tar xzf $MPC.tar.gz
		ln -sf $MPC mpc
	fi
fi

# set multiarch vars (if debian based)
if [ -x /usr/bin/dpkg-architecture ]; then
	BUILD_ARCH=$(/usr/bin/dpkg-architecture -q DEB_BUILD_MULTIARCH)
	HOST_ARCH=$(/usr/bin/dpkg-architecture -q DEB_HOST_MULTIARCH)
	TARGET_ARCH=$(/usr/bin/dpkg-architecture -q DEB_TARGET_MULTIARCH)
	MULTIARCH="--build=${BUILD_ARCH} --host=${HOST_ARCH} --target=${TARGET_ARCH}"
	LPATH="/usr/lib/${TARGET_ARCH}"
else
	MULTIARCH=""
	LPATH="/usr/lib"
fi

if [ x"${LIBRARY_PATH}" != x ]; then
	export LIBRARY_PATH="${LIBRARY_PATH}:${LPATH}"
else
	export LIBRARY_PATH="${LPATH}"
fi
unset LPATH

# create the build directories
cd ..
mkdir binutils-build gcc-build || true

cd binutils-build
# build binutils
../binutils-${BINUTILS_VERSION}/configure            \
    ${MULTIARCH}                                     \
    --disable-multilib                               \
    --prefix=${INSTALLDIR}                           \
&& make -j3 \
&& make install

cd ../gcc-build
# build gcc
../gcc-${GCC_VERSION}/configure                      \
    --prefix=${INSTALLDIR}                           \
    ${MULTIARCH}                                     \
    --with-as=${INSTALLDIR}/bin/as                   \
    --with-ld=${INSTALLDIR}/bin/ld                   \
    --enable-static                                  \
    --enable-shared                                  \
    --enable-threads=posix                           \
    --enable-__cxa_atexit                            \
    --enable-clocale=gnu                             \
    --enable-languages=c,c++                         \
    --disable-multilib                               \
    --with-system-zlib                               \
    --enable-gold=yes                                \
    --enable-ld=yes                                  \
    --enable-lto                                     \
    MAKEINFO=missing                                 \
&& make -j3                                          \
&& make install

# Notes
#
#   --enable-shared --enable-threads=posix --enable-__cxa_atexit: 
#       These parameters are required to build the C++ libraries to published standards.
#   
#   --enable-clocale=gnu: 
#       This parameter is a failsafe for incomplete locale data.
#   
#   --disable-multilib: 
#       This parameter ensures that files are created for the specific
#       architecture of your computer.
#        This will disable building 32-bit support on 64-bit systems where the
#        32 bit version of libc is not installed and you do not want to go
#        through the trouble of building it. Diagnosis: "Compiler build fails
#        with fatal error: gnu/stubs-32.h: No such file or directory"
#   
#   --with-system-zlib: 
#       Uses the system zlib instead of the bundled one. zlib is used for
#       compressing and uncompressing GCC's intermediate language in LTO (Link
#       Time Optimization) object files.
#   
#   --enable-languages=all
#   --enable-languages=c,c++,fortran,go,objc,obj-c++: 
#       This command identifies which languages to build. You may modify this
#       command to remove undesired language
#
#   --enable-gold[=ARG]
#       build gold [ARG={default,yes,no}]
#   --enable-ld[=ARG]
#       build ld [ARG={default,yes,no}]
#   --enable-lto
#       enable link time optimization support
