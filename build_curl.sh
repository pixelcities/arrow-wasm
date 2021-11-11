#!/bin/bash

set -e

EM_BIN=/tmp/emsdk-2.0.24/upstream/emscripten

wget https://curl.se/download/curl-7.78.0.tar.gz
tar xzf curl-7.78.0.tar.gz
mv curl-7.78.0 curl && rm curl-7.78.0.tar.gz

pushd curl

source /tmp/emsdk-2.0.24/emsdk_env.sh

# not implemented in emscripten
sed -i "s/fds_read, fds_write, fds_err, ptimeout/fds_read, fds_write, NULL, ptimeout/g" lib/select.c

emconfigure ./configure --disable-shared --disable-thread --disable-threaded-resolver --without-libpsl --disable-netrc --disable-unix-sockets --disable-ipv6 --disable-tftp --disable-ldap --disable-ldaps --disable-telnet --without-ssl #--with-openssl=/openssl
emmake make

popd
