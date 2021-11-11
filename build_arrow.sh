#!/bin/bash

set -ex

NPROC=$(nproc)

# Download & extract arrow
wget https://github.com/apache/arrow/archive/refs/tags/apache-arrow-4.0.1.tar.gz
tar zxf apache-arrow-4.0.1.tar.gz
mv arrow-apache-arrow-4.0.1 arrow && rm apache-arrow-4.0.1.tar.gz

mkdir -p $ARROW_BUILD_DIR
cd $ARROW_BUILD_DIR

source /tmp/emsdk-2.0.24/emsdk_env.sh

# Force the builder to find/use the headers
cp -r /openssl/include/ /build/arrow/src/

perl -0777 -i -pe 's/(find_(library|package|path)\(([^\)]|\n)*)/$1 CMAKE_FIND_ROOT_PATH_BOTH/ig' /usr/share/cmake-*/Modules/FindCURL.cmake
perl -0777 -i -pe 's/(find_(library|package|path)\(([^\)]|\n)*)/$1 CMAKE_FIND_ROOT_PATH_BOTH/ig' /usr/share/cmake-*/Modules/FindZLIB.cmake
perl -0777 -i -pe 's/(find_(library|package|path)\(([^\)]|\n)*)/$1 CMAKE_FIND_ROOT_PATH_BOTH/ig' /usr/share/cmake-*/Modules/FindOpenSSL.cmake
perl -0777 -i -pe 's/(find_(library|package|path)\(([^\)]|\n)*)/$1 CMAKE_FIND_ROOT_PATH_BOTH/ig' /usr/share/cmake-*/Modules/CMakeFindDependencyMacro.cmake

pushd /arrow

# Override some cmake settings
patch --force -p1 -i /patches/arrow_cmake.patch
cp /arrow/cpp/CMakeLists.txt /
truncate -s 0 /arrow/cpp/cmake_modules/SetupCxxFlags.cmake

# Disable threading in csv reader
patch --force -p1 -i /patches/arrow_reader.patch

# Revert back to some past commit without async ListObjectsV2
patch --force -p1 -i /patches/arrow_filesystem_s3fs.patch
popd

# Build arrow-wasm with csv, parquet, and parquet encryption support
cmake /arrow/cpp \
    -DCMAKE_TOOLCHAIN_FILE=/tmp/emsdk-2.0.24/upstream/emscripten/cmake/Modules/Platform/Emscripten.cmake \
    -DARROW_CSV=ON \
    -DARROW_PARQUET=ON \
    -DPARQUET_REQUIRE_ENCRYPTION=ON \
    -DARROW_DATASET=ON \
    -DARROW_FILESYSTEM=ON \
    -DARROW_S3=ON \
    -DARROW_HDFS=OFF \
    -DARROW_JSON=OFF \
    -DARROW_FLIGHT=OFF \
    -DARROW_JSON=OFF \
    -DARROW_IPC=OFF \
    -DARROW_COMPUTE=OFF \
    -DARROW_JEMALLOC=OFF \
    -DCURL_LIBRARY=/curl/lib/.libs/libcurl.a \
    -DCURL_INCLUDE_DIR=/curl/include
    $ARROW_CMAKE_OPTIONS

emmake make
emmake make install
