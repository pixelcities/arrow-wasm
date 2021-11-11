#!/bin/bash

set -e

EM_BIN=/tmp/emsdk-2.0.24/upstream/emscripten
source /tmp/emsdk-2.0.24/emsdk_env.sh

# aws-c-common
wget https://github.com/awslabs/aws-c-common/archive/refs/tags/v0.6.9.tar.gz -O aws-c-common.tar.gz
tar xzf aws-c-common.tar.gz
mv aws-c-common-0.6.9 aws-c-common && rm aws-c-common.tar.gz

pushd aws-c-common

cmake ../aws-c-common \
    -DCMAKE_TOOLCHAIN_FILE=/tmp/emsdk-2.0.24/upstream/emscripten/cmake/Modules/Platform/Emscripten.cmake \
    -DCMAKE_PREFIX_PATH=/build/arrow/awssdk_ep-install \
    -DCMAKE_INSTALL_PREFIX=/build/arrow/awssdk_ep-install \
    -DCMAKE_BUILD_TYPE=release \
    -DCMAKE_INSTALL_LIBDIR=lib \
    -DBUILD_SHARED_LIBS=OFF

emmake make
emmake make install

popd


# aws-checksums
wget https://github.com/awslabs/aws-checksums/archive/refs/tags/v0.1.7.tar.gz -O aws-checksums.tar.gz
tar xzf aws-checksums.tar.gz
mv aws-checksums-0.1.7 aws-checksums && rm aws-checksums.tar.gz

pushd aws-checksums

cmake ../aws-checksums \
    -DCMAKE_TOOLCHAIN_FILE=/tmp/emsdk-2.0.24/upstream/emscripten/cmake/Modules/Platform/Emscripten.cmake \
    -DCMAKE_INSTALL_PREFIX=/build/arrow/awssdk_ep-install \
    -DCMAKE_PREFIX_PATH=/build/arrow/awssdk_ep-install \
    -DBUILD_SHARED_LIBS=OFF

emmake make
emmake make install

popd


# aws-c-event-stream
wget https://github.com/awslabs/aws-c-event-stream/archive/refs/tags/v0.1.5.tar.gz -O aws-c-event-stream.tar.gz
tar xzf aws-c-event-stream.tar.gz
mv aws-c-event-stream-0.1.5 aws-c-event-stream && rm aws-c-event-stream.tar.gz

pushd aws-c-event-stream

perl -0777 -i -pe 's/(find_(library|package|path)\(([^\)]|\n)*)/$1 CMAKE_FIND_ROOT_PATH_BOTH/ig' /build/arrow/awssdk_ep-install/lib/cmake/AwsFindPackage.cmake
perl -0777 -i -pe 's/(find_(library|package|path)\(([^\)]|\n)*)/$1 CMAKE_FIND_ROOT_PATH_BOTH/ig' CMakeLists.txt

cmake ../aws-c-event-stream \
    -DCMAKE_TOOLCHAIN_FILE=/tmp/emsdk-2.0.24/upstream/emscripten/cmake/Modules/Platform/Emscripten.cmake \
    -DCMAKE_INSTALL_PREFIX=/build/arrow/awssdk_ep-install \
    -DCMAKE_PREFIX_PATH=/build/arrow/awssdk_ep-install \
    -DBUILD_SHARED_LIBS=OFF \
    -DCMAKE_BUILD_TYPE=release \
    -DCMAKE_INSTALL_LIBDIR=lib

emmake make
emmake make install

popd

