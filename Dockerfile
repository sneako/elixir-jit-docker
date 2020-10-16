# npiderman/elixir-jit

FROM ubuntu:focal-20200703 AS build

ENV ERLANG_REV 4a42e03c796ee23c6f8ce479722653ad82c10a8e
ENV ELIXIR_TAG v1.11.1

RUN apt-get update -&& \
  apt-get -y --no-install-recommends install \
    autoconf \
    dpkg-dev \
    gcc \
    g++ \
    make \
    libncurses-dev \
    unixodbc-dev \
    libssl-dev \
    libsctp-dev \
    wget \
    ca-certificates \
    pax-utils \
    git \
  && apt-get clean \
  && rm -rf /var/lib/apt/lists/*


RUN mkdir /OTP
RUN git clone -b master --single-branch https://github.com/erlang/otp /OTP 

WORKDIR /OTP

RUN git checkout $ERLANG_REV
RUN ./otp_build autoconf

RUN ./otp_build autoconf
RUN ./configure --with-ssl --enable-dirty-schedulers
RUN make -j$(getconf _NPROCESSORS_ONLN)
RUN make install
RUN find /usr/local -regex '/usr/local/lib/erlang/\(lib/\|erts-\).*/\(man\|doc\|obj\|c_src\|emacs\|info\|examples\)' | xargs rm -rf
RUN find /usr/local -name src | xargs -r find | grep -v '\.hrl$' | xargs rm -v || true
RUN find /usr/local -name src | xargs -r find | xargs rmdir -vp || true
RUN scanelf --nobanner -E ET_EXEC -BF '%F' --recursive /usr/local | xargs -r strip --strip-all
RUN scanelf --nobanner -E ET_DYN -BF '%F' --recursive /usr/local | xargs -r strip --strip-unneeded

ENV LANG=C.UTF-8

# Install Elixir
RUN git clone --depth 1 --branch $ELIXIR_TAG https://github.com/elixir-lang/elixir.git /elixir
WORKDIR /elixir
RUN git checkout 
RUN make clean test install

FROM ubuntu:focal-20200703 AS final

RUN apt-get update && \
  apt-get -y --no-install-recommends install \
    libodbc1 \
    libssl1.1 \
    libsctp1 \
  && apt-get clean \
  && rm -rf /var/lib/apt/lists/*

COPY --from=build /usr/local /usr/local
ENV LANG=C.UTF-8

