
set -e

wget https://github.com/emscripten-core/emsdk/archive/refs/tags/2.0.24.tar.gz -O /tmp/emsdk.tar.gz
cd /tmp
tar xzf emsdk.tar.gz
cd emsdk-2.0.24

./emsdk install latest
./emsdk activate latest

export PATH=$PATH:/tmp/emsdk-2.0.24/node/14.15.5_64bit/bin

cd ..
