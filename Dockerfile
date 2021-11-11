FROM ubuntu:focal

ENV DEBIAN_FRONTEND=noninteractive

RUN apt-get update -y -q && \
    apt-get install -y -q --no-install-recommends \
      build-essential \
      linux-headers-generic \
      wget \
      ca-certificates \
      python3 \
      cmake && \
    apt-get clean && rm -rf /var/lib/apt/lists*

COPY ./patches ./patches

COPY ./setup_emscripten.sh .
RUN ./setup_emscripten.sh

COPY ./build_openssl.sh .
RUN ./build_openssl.sh

COPY ./build_curl.sh .
RUN ./build_curl.sh

COPY ./build_zlib.sh .
RUN ./build_zlib.sh

COPY ./build_aws_c_deps.sh .
RUN ./build_aws_c_deps.sh

COPY ./build_aws_sdk.sh .
RUN ./build_aws_sdk.sh

COPY ./build_arrow.sh .
RUN ARROW_BUILD_DIR=/build/arrow ./build_arrow.sh

COPY ./build_wasm_module.sh .

VOLUME /src

CMD [ "./build_wasm_module.sh" ]
