#!/bin/bash

set -e

EM_BIN=/tmp/emsdk-2.0.24/upstream/emscripten
source /tmp/emsdk-2.0.24/emsdk_env.sh

wget https://github.com/aws/aws-sdk-cpp/archive/refs/tags/1.8.133.tar.gz -O aws-sdk-cpp.tar.gz
tar xzf aws-sdk-cpp.tar.gz
mv aws-sdk-cpp-1.8.133 aws-sdk-cpp && rm aws-sdk-cpp.tar.gz

pushd aws-sdk-cpp

# Emscripten root makes the find* utilities behave weirdly
perl -0777 -i -pe 's/(find_(library|package|path)\(([^\)]|\n)*)/$1 CMAKE_FIND_ROOT_PATH_BOTH/ig' CMakeLists.txt
perl -0777 -i -pe 's/(find_(library|package|path)\(([^\)]|\n)*)/$1 CMAKE_FIND_ROOT_PATH_BOTH/ig' aws-cpp-sdk-core/CMakeLists.txt
perl -0777 -i -pe 's/(find_(library|package|path)\(([^\)]|\n)*)/$1 CMAKE_FIND_ROOT_PATH_BOTH/ig' /usr/share/cmake-*/Modules/FindZLIB.cmake
perl -0777 -i -pe 's/(find_(library|package|path)\(([^\)]|\n)*)/$1 CMAKE_FIND_ROOT_PATH_BOTH/ig' /usr/share/cmake-*/Modules/FindOpenSSL.cmake
perl -0777 -i -pe 's/(find_(library|package|path)\(([^\)]|\n)*)/$1 CMAKE_FIND_ROOT_PATH_BOTH/ig' /usr/share/cmake-*/Modules/CMakeFindDependencyMacro.cmake

# Ugly hack to skip this block in favour of find_path, etc
perl -0777 -i -pe 's/if \(UNIX\)/if \(SKIPME\)/ig' /usr/share/cmake-*/Modules/FindOpenSSL.cmake

# We cannot do filesytem syscalls
patch --force -p1 -i /patches/aws_profile_config_loader.patch

# Sockets are also weird, let's strip out libcurl for fetch
patch --force -p1 -i /patches/curl_http_client.patch
patch --force -p1 -i /patches/curl_http_client_header.patch
patch --force -p1 -i /patches/curl_handle_container.patch
patch --force -p1 -i /patches/curl_handle_container_header.patch
patch --force -p1 -i /patches/client_configuration.patch

# Dummy curl
mkdir -p /curl/include
mkdir -p /curl/lib/.libs/
touch /curl/lib/.libs/libcurl.a
touch /curl/include/curl.h

cmake ../aws-sdk-cpp \
    -DCMAKE_TOOLCHAIN_FILE=/tmp/emsdk-2.0.24/upstream/emscripten/cmake/Modules/Platform/Emscripten.cmake \
    -DCMAKE_INSTALL_PREFIX=/build/arrow/awssdk_ep-install \
    -DCMAKE_PREFIX_PATH=/build/arrow/awssdk_ep-install \
    -DBUILD_SHARED_LIBS=OFF \
    -DCMAKE_BUILD_TYPE=release \
    -DCMAKE_INSTALL_LIBDIR=lib \
    -DENABLE_TESTING=OFF \
    -DENABLE_UNITY_BUILD=ON \
    -DOPENSSL_ROOT_DIR=/openssl \
    -DOPENSSL_INCLUDE_DIR=/openssl/include \
    -DCURL_LIBRARY=/curl/lib/.libs/libcurl.a \
    -DCURL_INCLUDE_DIR=/curl/include \
    -DBUILD_DEPS=OFF \
    -DBUILD_ONLY="config;s3;transfer;identity-management;sts" \
    -DMINIMIZE_SIZE=ON \
    -DZLIB_ROOT=/zlib \
    -DOPENSSL_USE_STATIC_LIBS=TRUE

emmake make
emmake make install

popd

