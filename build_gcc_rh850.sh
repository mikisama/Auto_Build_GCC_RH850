# exit if command failed.
set -o errexit
# exit if pipe failed.
set -o pipefail
# exit if variable not set.
set -o nounset

# sed -i 's/archive.ubuntu.com/mirrors.aliyun.com/g' /etc/apt/sources.list

apt update -y
apt install build-essential mingw-w64 wget texinfo bison zip -y

BINUTILS_VERSION="2.34"
GCC_VERSION="9.3.0"
NEWLIB_VERSION="3.3.0"

BUILD="x86_64-linux-gnu"
LINUX_HOST="x86_64-linux-gnu"
WINDOWS_HOST="x86_64-w64-mingw32"
TARGET="v850-elf"
BASE_PATH="/tmp/work"

PATCH_PATH=$(dirname $(readlink -f "$0"))/patch
SOURCE_PATH="${BASE_PATH}/source"
BUILD_LINUX_PATH="${BASE_PATH}/build/linux"
BUILD_WINDOWS_PATH="${BASE_PATH}/build/win32"
INSTALL_LINUX_PATH="${BASE_PATH}/install/v850-elf-gcc-linux-x64"
INSTALL_WINDOWS_PATH="${BASE_PATH}/install/v850-elf-gcc-win32-x64"
STAGE_PATH="${BASE_PATH}/stage"
PATH=$PATH:${INSTALL_LINUX_PATH}/bin

mkdir -p ${SOURCE_PATH}
mkdir -p ${BUILD_LINUX_PATH}
mkdir -p ${BUILD_WINDOWS_PATH}
mkdir -p ${INSTALL_LINUX_PATH}
mkdir -p ${INSTALL_WINDOWS_PATH}
mkdir -p ${STAGE_PATH}

# download tarballs
if [ ! -e ${STAGE_PATH}/download_binutils ]
then
    wget -c -P ${SOURCE_PATH} http://ftpmirror.gnu.org/binutils/binutils-${BINUTILS_VERSION}.tar.gz
    touch ${STAGE_PATH}/download_binutils
fi

if [ ! -e ${STAGE_PATH}/download_gcc ]
then
    wget -c -P ${SOURCE_PATH} http://ftpmirror.gnu.org/gcc/gcc-${GCC_VERSION}/gcc-${GCC_VERSION}.tar.gz
    touch ${STAGE_PATH}/download_gcc
fi

if [ ! -e ${STAGE_PATH}/download_newlib ]
then
    wget -c -P ${SOURCE_PATH} ftp://sourceware.org/pub/newlib/newlib-${NEWLIB_VERSION}.tar.gz
    touch ${STAGE_PATH}/download_newlib
fi

# extract tarballs
if [ ! -e ${STAGE_PATH}/extract_binutils ]
then
    tar -xvf ${SOURCE_PATH}/binutils-${BINUTILS_VERSION}.tar.gz -C ${SOURCE_PATH}
    touch ${STAGE_PATH}/extract_binutils
fi

if [ ! -e ${STAGE_PATH}/extract_gcc ]
then
    tar -xvf ${SOURCE_PATH}/gcc-${GCC_VERSION}.tar.gz -C ${SOURCE_PATH}
    touch ${STAGE_PATH}/extract_gcc
fi

if [ ! -e ${STAGE_PATH}/extract_newlib ]
then
    tar -xvf ${SOURCE_PATH}/newlib-${NEWLIB_VERSION}.tar.gz -C ${SOURCE_PATH}
    touch ${STAGE_PATH}/extract_newlib
fi

# download gcc prerequisites
cd ${SOURCE_PATH}/gcc-${GCC_VERSION}
./contrib/download_prerequisites

# do patches
if [ ! -e ${STAGE_PATH}/do_patch ]
then
    cd ${SOURCE_PATH}
    patch -p0 -i ${PATCH_PATH}/gcc.patch
    patch -p0 -i ${PATCH_PATH}/newlib.patch
    touch ${STAGE_PATH}/do_patch
fi

# build linux toolchain
if [ ! -e ${STAGE_PATH}/build_linux_binutils ]
then
    mkdir -p ${BUILD_LINUX_PATH}/binutils
    cd ${BUILD_LINUX_PATH}/binutils

    ${SOURCE_PATH}/binutils-${BINUTILS_VERSION}/configure \
        --build=${BUILD} \
        --host=${LINUX_HOST} \
        --target=${TARGET} \
        --prefix=${INSTALL_LINUX_PATH} \
        --disable-nls

    make
    make install-strip

    touch ${STAGE_PATH}/build_linux_binutils
fi

if [ ! -e ${STAGE_PATH}/build_linux_gcc_1st ]
then
    mkdir -p ${BUILD_LINUX_PATH}/gcc_1st
    cd ${BUILD_LINUX_PATH}/gcc_1st

    ${SOURCE_PATH}/gcc-${GCC_VERSION}/configure \
        --build=${BUILD} \
        --host=${LINUX_HOST} \
        --target=${TARGET} \
        --prefix=${INSTALL_LINUX_PATH} \
        --enable-languages=c \
        --without-headers \
        --with-newlib  \
        --with-gnu-as \
        --with-gnu-ld \
        --disable-threads \
        --disable-libssp \
        --disable-shared \
        --disable-nls

    make all-gcc
    make install-strip-gcc

    touch ${STAGE_PATH}/build_linux_gcc_1st
fi

if [ ! -e ${STAGE_PATH}/build_linux_newlib ]
then
    mkdir -p ${BUILD_LINUX_PATH}/newlib
    cd ${BUILD_LINUX_PATH}/newlib

    ${SOURCE_PATH}/newlib-${NEWLIB_VERSION}/configure \
        --build=${BUILD} \
        --host=${LINUX_HOST} \
        --target=${TARGET} \
        --prefix=${INSTALL_LINUX_PATH} \
        --enable-newlib-nano-malloc \
        --enable-newlib-nano-formatted-io \
        --enable-newlib-reent-small \
        --disable-nls

    # do not use GP based addressing

    #if defined(__v850) && !defined(__rtems__)
    #define __ATTRIBUTE_IMPURE_PTR__ __attribute__((__sda__))
    #endif

    make CFLAGS_FOR_TARGET="-gdwarf-2 -fdata-sections -ffunction-sections -g -Os -D__rtems__"
    make install

    touch ${STAGE_PATH}/build_linux_newlib
fi

if [ ! -e ${STAGE_PATH}/build_linux_gcc_2nd ]
then
    mkdir -p ${BUILD_LINUX_PATH}/gcc_2nd
    cd ${BUILD_LINUX_PATH}/gcc_2nd

    ${SOURCE_PATH}/gcc-${GCC_VERSION}/configure \
        --build=${BUILD} \
        --host=${LINUX_HOST} \
        --target=${TARGET} \
        --prefix=${INSTALL_LINUX_PATH} \
        --enable-languages=c,c++ \
        --with-headers \
        --with-newlib  \
        --with-gnu-as \
        --with-gnu-ld \
        --disable-threads \
        --disable-libssp \
        --disable-shared \
        --disable-nls

    make
    make install-strip

    touch ${STAGE_PATH}/build_linux_gcc_2nd
fi

# build win32 toolchain
if [ ! -e ${STAGE_PATH}/build_win32_binutils ]
then
    mkdir -p ${BUILD_WINDOWS_PATH}/binutils
    cd ${BUILD_WINDOWS_PATH}/binutils

    ${SOURCE_PATH}/binutils-${BINUTILS_VERSION}/configure \
        --build=${BUILD} \
        --host=${WINDOWS_HOST} \
        --target=${TARGET} \
        --prefix=${INSTALL_WINDOWS_PATH} \
        --disable-nls

    make
    make install-strip

    touch ${STAGE_PATH}/build_win32_binutils
fi

if [ ! -e ${STAGE_PATH}/build_win32_gcc_1st ]
then
    mkdir -p ${BUILD_WINDOWS_PATH}/gcc_1st
    cd ${BUILD_WINDOWS_PATH}/gcc_1st

    ${SOURCE_PATH}/gcc-${GCC_VERSION}/configure \
        --build=${BUILD} \
        --host=${WINDOWS_HOST} \
        --target=${TARGET} \
        --prefix=${INSTALL_WINDOWS_PATH} \
        --enable-languages=c \
        --without-headers \
        --with-newlib  \
        --with-gnu-as \
        --with-gnu-ld \
        --disable-threads \
        --disable-libssp \
        --disable-shared \
        --disable-nls

    make all-gcc
    make install-strip-gcc

    touch ${STAGE_PATH}/build_win32_gcc_1st
fi

if [ ! -e ${STAGE_PATH}/build_win32_newlib ]
then
    mkdir -p ${BUILD_WINDOWS_PATH}/newlib
    cd ${BUILD_WINDOWS_PATH}/newlib

    ${SOURCE_PATH}/newlib-${NEWLIB_VERSION}/configure \
        --build=${BUILD} \
        --host=${WINDOWS_HOST} \
        --target=${TARGET} \
        --prefix=${INSTALL_WINDOWS_PATH} \
        --enable-newlib-nano-malloc \
        --enable-newlib-nano-formatted-io \
        --enable-newlib-reent-small \
        --disable-nls

    # do not use GP based addressing

    #if defined(__v850) && !defined(__rtems__)
    #define __ATTRIBUTE_IMPURE_PTR__ __attribute__((__sda__))
    #endif

    make CFLAGS_FOR_TARGET="-gdwarf-2 -fdata-sections -ffunction-sections -g -Os -D__rtems__"
    make install

    touch ${STAGE_PATH}/build_win32_newlib
fi

if [ ! -e ${STAGE_PATH}/build_win32_gcc_2nd ]
then
    mkdir -p ${BUILD_WINDOWS_PATH}/gcc_2nd
    cd ${BUILD_WINDOWS_PATH}/gcc_2nd

    ${SOURCE_PATH}/gcc-${GCC_VERSION}/configure \
        --build=${BUILD} \
        --host=${WINDOWS_HOST} \
        --target=${TARGET} \
        --prefix=${INSTALL_WINDOWS_PATH} \
        --enable-languages=c,c++ \
        --with-headers \
        --with-newlib  \
        --with-gnu-as \
        --with-gnu-ld \
        --disable-threads \
        --disable-libssp \
        --disable-shared \
        --disable-nls

    make
    make install-strip

    touch ${STAGE_PATH}/build_win32_gcc_2nd
fi

# zip toolchain
cd ${BASE_PATH}/install
zip -r v850-elf-gcc-linux-x64.zip v850-elf-gcc-linux-x64
zip -r v850-elf-gcc-win32-x64.zip v850-elf-gcc-win32-x64
