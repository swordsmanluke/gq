# Cacheable layer for building
FROM ubuntu as tebako-base

ENV DEBIAN_FRONTEND=noninteractive
ENV TZ=Etc/UTC

RUN apt-get update
RUN apt-get install -y software-properties-common
RUN add-apt-repository -y ppa:ubuntu-toolchain-r/test
RUN apt-get install -y gcc-10 g++-10

RUN apt-get install -y curl git ruby ruby-dev pkg-config bison flex make autoconf
# RUN curl https://apt.kitware.com/kitware-archive.sh | bash
RUN apt-get install -y cmake

RUN apt-get -y install sudo git curl build-essential pkg-config bison flex autoconf \
   binutils-dev libevent-dev acl-dev libfmt-dev libjemalloc-dev libiberty-dev    \
   libdouble-conversion-dev liblz4-dev liblzma-dev libssl-dev libunwind-dev      \
   libboost-filesystem-dev libboost-program-options-dev libboost-system-dev      \
   libboost-iostreams-dev  libboost-date-time-dev libboost-context-dev           \
   libboost-regex-dev libboost-thread-dev libbrotli-dev libdwarf-dev libelf-dev  \
   libgoogle-glog-dev libffi-dev libgdbm-dev libyaml-dev libncurses-dev          \
   libreadline-dev libutfcpp-dev libncurses-dev libreadline-dev gcc-10 g++-10    \
   ruby-dev ruby-bundler

RUN gem install tebako

RUN tebako setup 

# OKay, ready to build
FROM tebako-base as gem-stage

ENV BUNDLE_SILENCE_ROOT_WARNING=1

WORKDIR /project

RUN gem install bundler=2.5.6

CMD bundle install && \
    bundle exec rake install && \
    tebako press \
	--root=. \
	--entry-point=bin/gq \
	--output=out/gq

