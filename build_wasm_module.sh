#!/bin/bash

set -ex

cd /src

source /tmp/emsdk-3.1.15/emsdk_env.sh

cmake /src \
    -DCMAKE_TOOLCHAIN_FILE=/tmp/emsdk-3.1.15/upstream/emscripten/cmake/Modules/Platform/Emscripten.cmake

emmake make

# Add subresource integrity
SRI_HASH=$(cat arrow_wasm.wasm | openssl dgst -sha384 -binary | openssl base64 -A)
sed -i "s/\(fetch([a-zA-Z]\+, { credentials: 'same-origin'\)/\1, integrity: 'sha384-${SRI_HASH}'/g" arrow_wasm.js
