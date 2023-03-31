FROM alpine:3.17 as base

RUN apk add --update \
    git \
    gcc \
    file \
    make \
    musl-dev \
    openssl-dev \
    openssl-libs-static \
    cmake \
    build-base \
    perl \
    go \
    linux-headers \
    cargo \
    libtool \
    autoconf \
    automake \
    pkgconfig \
    ca-certificates \
  && update-ca-certificates

RUN apk add curl \
  &&  curl https://sh.rustup.rs -sSf | sh -s -- -y -q \
  && apk del curl

WORKDIR /app

ARG QUICHE_VERSION=0.17.1
ARG CURL_VERSION=curl-8_0_1

RUN git clone --branch ${QUICHE_VERSION} \
  --recursive https://github.com/cloudflare/quiche.git

RUN git clone --branch ${CURL_VERSION} \
  https://github.com/curl/curl.git

# Build BoringSSL
RUN cd /app/quiche/quiche/deps/boringssl/ \
  && mkdir -p build \
  && cd /app/quiche/quiche/deps/boringssl/build/ \
  && cmake -DCMAKE_POSITION_INDEPENDENT_CODE=on .. \
  && make \
  && cd /app/quiche/quiche/deps/boringssl/ \
  && mkdir -p .openssl/lib \
  && cp build/libcrypto.a build/libssl.a .openssl/lib \
  && cp -R src/include/ .openssl/

# Build quiche
RUN cd /app/quiche/ \
  && QUICHE_BSSL_PATH=$PWD/quiche/deps/boringssl \
  && source "$HOME/.cargo/env" \
  && rm -rf $HOME/.cargo/registry/* \
  &&  cargo build --release --features ffi,pkg-config-meta,qlog

# # Build curl
RUN cp -R /app/quiche/quiche/deps/boringssl/src/include/ /app/quiche/quiche/deps/boringssl/.openssl/ \
  && cd /app/curl \
  && ./buildconf \
  && ./configure \
    LDFLAGS="-Wl,-rpath,/app/quiche/target/release" \
    --with-ssl=/app/quiche/quiche/deps/boringssl/.openssl \
    --with-quiche=/app/quiche/target/release \
    --disable-shared \
    --enable-alt-svc \
  && make curl_LDFLAGS=-all-static \
  && strip /app/curl/src/curl

FROM alpine:3.17

COPY --from=base /etc/ssl/certs/ /etc/ssl/certs/
COPY --from=base /app/curl/src/curl /curl

RUN apk add --update \
  gcc \
  tcpdump

ENTRYPOINT ["/curl"]
