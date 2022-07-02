#!/bin/bash

set -e

EM_BIN=/tmp/emsdk-2.0.24/upstream/emscripten
source /tmp/emsdk-2.0.24/emsdk_env.sh

wget https://zlib.net/fossils/zlib-1.2.11.tar.gz
tar xzf zlib-1.2.11.tar.gz
mv zlib-1.2.11 zlib && rm zlib-1.2.11.tar.gz

pushd zlib

emconfigure ./configure --static
emmake make
emmake make install

popd

