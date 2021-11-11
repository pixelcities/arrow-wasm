#!/bin/bash

set -e

EM_BIN=/tmp/emsdk-2.0.24/upstream/emscripten

wget https://www.openssl.org/source/openssl-1.1.1k.tar.gz
tar xzf openssl-1.1.1k.tar.gz
mv openssl-1.1.1k openssl && rm openssl-1.1.1k.tar.gz

pushd openssl

source /tmp/emsdk-2.0.24/emsdk_env.sh

# Some weird path substitution bug
sed -i 's/CROSS_COMPILE/x/g' $EM_BIN/tools/building.py

emconfigure ./Configure -no-asm no-unit-test no-tests no-ui-console no-threads no-ssl-trace no-stdio no-ssl2 no-ssl3 no-comp no-hw no-engine no-err no-shared no-psk no-srp no-ec2m no-weak-ssl-ciphers no-dso --openssldir=built linux-generic32
emmake make
emmake make install

popd
