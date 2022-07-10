#!/bin/bash

set -ex

cd /src

source /tmp/emsdk-3.1.15/emsdk_env.sh

cmake /src \
    -DCMAKE_TOOLCHAIN_FILE=/tmp/emsdk-3.1.15/upstream/emscripten/cmake/Modules/Platform/Emscripten.cmake

emmake make

