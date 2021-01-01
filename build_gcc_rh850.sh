#!/bin/bash

set -e
set -o pipefail

sudo apt update -y
sudo apt install gcc g++ mingw-w64 make m4 texinfo zip -y

TOOLCHAIN_NAME="gcc-v850-elf"
TOOLCHAIN_PATH="/tmp/opt/${TOOLCHAIN_NAME}-linux"

BUILD="x86_64-linux-gnu"
HOST="x86_64-linux-gnu"
TARGET_ARCH="v850-elf"

NUMJOBS="-j$(nproc)"
export PATH=$PATH:${TOOLCHAIN_PATH}/bin

DOWNLOAD_PATH="/tmp/download"
SOURCES_PATH="/tmp/sources"
BUILD_PATH="/tmp/build_linux"

# prepare install path
rm -rf ${TOOLCHAIN_PATH}
mkdir -p ${TOOLCHAIN_PATH}

# prepare temporary build folders
rm -rf ${SOURCES_PATH}
rm -rf ${BUILD_PATH}

mkdir -p ${SOURCES_PATH}
mkdir -p ${BUILD_PATH}

# software versions
BINUTILS_VERSION="2.34"
GCC_VERSION="9.3.0"
GMP_VERSION="6.2.0"
MPC_VERSION="1.1.0"
MPFR_VERSION="4.0.2"
GDB_VERSION="9.1"
NEWLIB_VERSION="3.3.0"

# download sources
wget -c -P ${DOWNLOAD_PATH} https://mirrors.aliyun.com/gnu/binutils/binutils-${BINUTILS_VERSION}.tar.gz
wget -c -P ${DOWNLOAD_PATH} https://mirrors.aliyun.com/gnu/gcc/gcc-${GCC_VERSION}/gcc-${GCC_VERSION}.tar.gz
wget -c -P ${DOWNLOAD_PATH} https://mirrors.aliyun.com/gnu/gmp/gmp-${GMP_VERSION}.tar.bz2
wget -c -P ${DOWNLOAD_PATH} https://mirrors.aliyun.com/gnu/mpc/mpc-${MPC_VERSION}.tar.gz
wget -c -P ${DOWNLOAD_PATH} https://mirrors.aliyun.com/gnu/mpfr/mpfr-${MPFR_VERSION}.tar.gz
# wget -c -P ${DOWNLOAD_PATH} https://mirrors.aliyun.com/gnu/gdb/gdb-${GDB_VERSION}.tar.gz
wget -c -P ${DOWNLOAD_PATH} ftp://sourceware.org/pub/newlib/newlib-${NEWLIB_VERSION}.tar.gz

for f in $(find ${DOWNLOAD_PATH} -name *.tar.gz)
do
    tar zxvf "$f" -C ${SOURCES_PATH}
done

for f in $(find ${DOWNLOAD_PATH} -name *.tar.bz2)
do
    tar jxvf "$f" -C ${SOURCES_PATH}
done

(cd ${SOURCES_PATH}/gcc-${GCC_VERSION}/ && ln -sf ../gmp-${GMP_VERSION} gmp)
(cd ${SOURCES_PATH}/gcc-${GCC_VERSION}/ && ln -sf ../mpc-${MPC_VERSION} mpc)
(cd ${SOURCES_PATH}/gcc-${GCC_VERSION}/ && ln -sf ../mpfr-${MPFR_VERSION} mpfr)

# build binutils
mkdir -p ${BUILD_PATH}/binutils
cd ${BUILD_PATH}/binutils

${SOURCES_PATH}/binutils-${BINUTILS_VERSION}/configure \
    --build=${BUILD} \
    --host=${HOST} \
    --target=${TARGET_ARCH} \
    --prefix=${TOOLCHAIN_PATH} \
    --disable-nls \
    2>&1 | tee configure.out

make -w ${NUMJOBS} 2>&1 | tee make.out
make -w install-strip 2>&1 | tee make_install.out

# build gcc - 1st pass
mkdir -p ${BUILD_PATH}/gcc_1st
cd ${BUILD_PATH}/gcc_1st

${SOURCES_PATH}/gcc-${GCC_VERSION}/configure \
    --build=${BUILD} \
    --host=${HOST} \
    --target=${TARGET_ARCH} \
    --prefix=${TOOLCHAIN_PATH} \
    --enable-languages=c \
    --without-headers \
    --with-gnu-as \
    --with-gnu-ld \
    --with-newlib \
    --disable-libssp \
    --disable-threads \
    --disable-shared \
    --disable-nls \
    2>&1 | tee configure.out

make -w ${NUMJOBS} all-gcc 2>&1 | tee make.out
make -w install-strip-gcc 2>&1 | tee make_install.out

# build newlib
mkdir -p ${BUILD_PATH}/newlib
cd ${BUILD_PATH}/newlib

${SOURCES_PATH}/newlib-${NEWLIB_VERSION}/configure \
    --build=${BUILD} \
    --host=${HOST} \
    --target=${TARGET_ARCH} \
    --prefix=${TOOLCHAIN_PATH} \
    --disable-nls \
    2>&1 | tee configure.out

make -w ${NUMJOBS} TARGET_CFLAGS="-gdwarf-2" 2>&1 | tee make.out
make -w install 2>&1 | tee make_install.out

# build gcc - 2nd pass
mkdir -p ${BUILD_PATH}/gcc_2nd
cd ${BUILD_PATH}/gcc_2nd

${SOURCES_PATH}/gcc-${GCC_VERSION}/configure \
    --build=${BUILD} \
    --host=${HOST} \
    --target=${TARGET_ARCH} \
    --prefix=${TOOLCHAIN_PATH} \
    --enable-languages=c,c++ \
    --with-headers \
    --with-gnu-as \
    --with-gnu-ld \
    --with-newlib \
    --disable-libssp \
    --disable-threads \
    --disable-shared \
    --disable-nls \
    2>&1 | tee configure.out

make -w ${NUMJOBS} 2>&1 | tee make.out
make -w install-strip 2>&1 | tee make_install.out

# run test compilation - C
echo "
int main() {
    int a = 0;
    return 0;
}
" > ${BUILD_PATH}/rh850_test.c
${TARGET_ARCH}-gcc -mv850e3v5 -mloop -mrh850-abi ${BUILD_PATH}/rh850_test.c -o ${BUILD_PATH}/rh850_test_c.elf
${TARGET_ARCH}-size --format=berkeley ${BUILD_PATH}/rh850_test_c.elf

# run test compilation - C++
echo "
#include <vector>
#include <array>
auto get_value() { return 0.0; }
int main() {
    std::vector<int> test_vec;
    std::array<int, 5> test_array{ {3, 4, 5, 1, 2} };
    for(auto i: test_array)
        test_vec.push_back(i);
    double value = get_value();
    return 0;
}
" > ${BUILD_PATH}/rh850_test.cpp
${TARGET_ARCH}-g++ -mv850e3v5 -mloop -mrh850-abi --std=c++14 ${BUILD_PATH}/rh850_test.cpp -o ${BUILD_PATH}/rh850_test_cpp.elf
${TARGET_ARCH}-size --format=berkeley ${BUILD_PATH}/rh850_test_cpp.elf

# build for win

TOOLCHAIN_PATH="/tmp/opt/${TOOLCHAIN_NAME}-windows"
HOST="x86_64-w64-mingw32"
# HOST="i686-w64-mingw32"

BUILD_PATH="/tmp/build_mingw32"

# prepare install path
rm -rf ${TOOLCHAIN_PATH}
mkdir -p ${TOOLCHAIN_PATH}

# prepare temporary build folders
rm -rf ${SOURCES_PATH}
rm -rf ${BUILD_PATH}

mkdir -p ${SOURCES_PATH}
mkdir -p ${BUILD_PATH}

for f in $(find ${DOWNLOAD_PATH} -name *.tar.gz)
do
    tar zxvf "$f" -C ${SOURCES_PATH}
done

for f in $(find ${DOWNLOAD_PATH} -name *.tar.bz2)
do
    tar jxvf "$f" -C ${SOURCES_PATH}
done

(cd ${SOURCES_PATH}/gcc-${GCC_VERSION}/ && ln -sf ../gmp-${GMP_VERSION} gmp)
(cd ${SOURCES_PATH}/gcc-${GCC_VERSION}/ && ln -sf ../mpc-${MPC_VERSION} mpc)
(cd ${SOURCES_PATH}/gcc-${GCC_VERSION}/ && ln -sf ../mpfr-${MPFR_VERSION} mpfr)

# build binutils
mkdir -p ${BUILD_PATH}/binutils
cd ${BUILD_PATH}/binutils

${SOURCES_PATH}/binutils-${BINUTILS_VERSION}/configure \
    --build=${BUILD} \
    --host=${HOST} \
    --target=${TARGET_ARCH} \
    --prefix=${TOOLCHAIN_PATH} \
    --disable-nls \
    2>&1 | tee configure.out

make -w ${NUMJOBS} 2>&1 | tee make.out
make -w install-strip 2>&1 | tee make_install.out

# build gcc - 1st pass
mkdir -p ${BUILD_PATH}/gcc_1st
cd ${BUILD_PATH}/gcc_1st

${SOURCES_PATH}/gcc-${GCC_VERSION}/configure \
    --build=${BUILD} \
    --host=${HOST} \
    --target=${TARGET_ARCH} \
    --prefix=${TOOLCHAIN_PATH} \
    --enable-languages=c \
    --without-headers \
    --with-gnu-as \
    --with-gnu-ld \
    --with-newlib \
    --disable-libssp \
    --disable-threads \
    --disable-shared \
    --disable-nls \
    2>&1 | tee configure.out

make -w ${NUMJOBS} all-gcc 2>&1 | tee make.out
make -w install-strip-gcc 2>&1 | tee make_install.out

# build newlib
mkdir -p ${BUILD_PATH}/newlib
cd ${BUILD_PATH}/newlib

${SOURCES_PATH}/newlib-${NEWLIB_VERSION}/configure \
    --build=${BUILD} \
    --host=${HOST} \
    --target=${TARGET_ARCH} \
    --prefix=${TOOLCHAIN_PATH} \
    --disable-nls \
    2>&1 | tee configure.out

make -w ${NUMJOBS} TARGET_CFLAGS="-gdwarf-2" 2>&1 | tee make.out
make -w install 2>&1 | tee make_install.out

# build gcc - 2nd pass
mkdir -p ${BUILD_PATH}/gcc_2nd
cd ${BUILD_PATH}/gcc_2nd

${SOURCES_PATH}/gcc-${GCC_VERSION}/configure \
    --build=${BUILD} \
    --host=${HOST} \
    --target=${TARGET_ARCH} \
    --prefix=${TOOLCHAIN_PATH} \
    --enable-languages=c,c++ \
    --with-headers \
    --with-gnu-as \
    --with-gnu-ld \
    --with-newlib \
    --disable-libssp \
    --disable-threads \
    --disable-shared \
    --disable-nls \
    2>&1 | tee configure.out

make -w ${NUMJOBS} 2>&1 | tee make.out
make -w install-strip 2>&1 | tee make_install.out

# zip toolchain
cd /tmp/opt
zip -r gcc-v850-elf-linux.zip gcc-v850-elf-linux
zip -r gcc-v850-elf-windows.zip gcc-v850-elf-windows
