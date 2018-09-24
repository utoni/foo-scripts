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
CPUCORES=$(cat /proc/cpuinfo | grep -E '^processor' | wc -l)

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

# check build dirs existence
BIN_BUILD="binutils-${BINUTILS_VERSION}-build"
if [ -d ${BIN_BUILD} ]; then
	ANSW=$(whiptail --clear --menu 'binutils-build exists: delete?' 15 35 5 y yes n no 3>&1 1>&2 2>&3)
	if [ x"${ANSW}" = x'y' ]; then
		rm -rf ${BIN_BUILD}
	fi
fi
GCC_BUILD="gcc-${GCC_VERSION}-build"
if [ -d ${GCC_BUILD} ]; then
	ANSW=$(whiptail --clear --menu 'gcc-build exists: delete?' 15 35 5 y yes n no 3>&1 1>&2 2>&3)
	if [ x"${ANSW}" = x'y' ]; then
		rm -rf ${GCC_BUILD}
	fi
fi

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
	wget -O "binutils-${BINUTILS_VERSION}.tar.gz" "${BIN_DLSITE}/binutils-${BINUTILS_VERSION}.tar.gz"
fi
test -d ${BIN_BUILD} || tar -xvf binutils-${BINUTILS_VERSION}.tar.gz
if [ ! -f "gcc-${GCC_VERSION}.tar.bz2" -a ! -f "gcc-${GCC_VERSION}.tar.gz" ]; then
	wget -O "gcc-${GCC_VERSION}.tar.bz2" "${GCC_DLSITE}/gcc-${GCC_VERSION}/gcc-${GCC_VERSION}.tar.bz2" || \
        { rm -f "gcc-${GCC_VERSION}.tar.bz2"; \
            wget -O "gcc-${GCC_VERSION}.tar.gz" "${GCC_DLSITE}/gcc-${GCC_VERSION}/gcc-${GCC_VERSION}.tar.gz"; }
fi
test ! -d ${GCC_BUILD} -a -r gcc-${GCC_VERSION}.tar.bz2 && tar -xvf gcc-${GCC_VERSION}.tar.bz2
test ! -d ${GCC_BUILD} -a -r gcc-${GCC_VERSION}.tar.gz && tar -xvf gcc-${GCC_VERSION}.tar.gz

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
		wget -O "$MPFR.tar.bz2" "ftp://gcc.gnu.org/pub/gcc/infrastructure/$MPFR.tar.bz2"
		tar xjf $MPFR.tar.bz2
		ln -sf $MPFR mpfr
	fi
	if [ ! -f "$GMP.tar.bz2" -o ! -h gmp ]; then
		rm -rf gmp
		wget -O "$GMP.tar.bz2" "ftp://gcc.gnu.org/pub/gcc/infrastructure/$GMP.tar.bz2"
		tar xjf $GMP.tar.bz2
		ln -sf $GMP gmp
	fi
	if [ ! -f "$MPC.tar.gz" -o ! -h mpc ]; then
		rm -rf mpc
		wget -O "$MPC.tar.gz" "ftp://gcc.gnu.org/pub/gcc/infrastructure/$MPC.tar.gz"
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
mkdir ${BIN_BUILD} ${GCC_BUILD} || true

cd ${BIN_BUILD}
# build binutils
../binutils-${BINUTILS_VERSION}/configure            \
    ${MULTIARCH}                                     \
    --disable-multilib                               \
    --prefix=${INSTALLDIR}                           \
    --disable-nls                                    \
    --enable-gold=default                            \
&& sed -i 's|^MAKEINFO\s\+=\s\+makeinfo$|MAKEINFO = true|' ./Makefile \
&& make -j${CPUCORES:-2}                             \
&& make install

cd ../${GCC_BUILD}
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
    --enable-languages=c,c++,go                      \
    --disable-multilib                               \
    --with-system-zlib                               \
    --enable-gold=yes                                \
    --enable-ld=yes                                  \
    --enable-lto                                     \
    --disable-nls                                    \
&& sed -i 's|^MAKEINFO\s\+=\s\+makeinfo$|MAKEINFO = true|' ./Makefile \
&& make -j${CPUCORES:-2}                             \
&& make install

# write activation script to gcc root
cat << EOF > "${INSTALLDIR}/activate.sh"
#!/bin/bash

DIR="\$(realpath "\$(dirname "\${BASH_SOURCE}")")"
echo "*** ROOT: \${DIR}"
export PATH="\${DIR}/bin:\${DIR}/usr/bin:\${PATH}"
export CMAKE_C_COMPILER="\${DIR}/bin/gcc"
export CMAKE_CXX_COMPILER="\${DIR}/bin/g++"
export CC="\${CMAKE_C_COMPILER}"
export CXX="\${CMAKE_CXX_COMPILER}"
EOF
chmod +x "${INSTALLDIR}/activate.sh"

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
