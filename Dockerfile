FROM alpine:edge

RUN apk update && apk add crystal shards gcc g++ cmake make

RUN apk add \
    vips-dev \
    libressl-dev \
    zlib-dev \
    lexbor-dev \
    yaml-dev \
    discount-dev \
    libxml2-dev
