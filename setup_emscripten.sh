
set -e

wget https://github.com/emscripten-core/emsdk/archive/refs/tags/3.1.15.tar.gz -O /tmp/emsdk.tar.gz
cd /tmp
tar xzf emsdk.tar.gz
cd emsdk-3.1.15

./emsdk install latest
./emsdk activate latest

export PATH=$PATH:/tmp/emsdk-3.1.15/node/14.18.2_64bit/bin

cd ..
