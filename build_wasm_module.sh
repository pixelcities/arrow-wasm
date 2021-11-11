#!/bin/bash

set -ex

cd /src

source /tmp/emsdk-2.0.24/emsdk_env.sh

cmake /src \
    -DCMAKE_TOOLCHAIN_FILE=/tmp/emsdk-2.0.24/upstream/emscripten/cmake/Modules/Platform/Emscripten.cmake

emmake make

