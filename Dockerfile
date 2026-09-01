# syntax=docker/dockerfile:1
FROM quay.io/almalinuxorg/9-base:9

ARG NPROC=4
ARG ROOT_VERSION=v6-32-06
ARG ARTEMIS_BRANCH=develop
ARG LIBZMQ_VERSION=v4.3.5
ARG HIREDIS_VERSION=v1.1.0
ARG REDIS_PLUS_PLUS_VERSION=1.3.6
ARG YAML_CPP_VERSION=0.8.0

ENV ARTEMIS_ROOT=/opt/artemis
ENV ROOTSYS=/opt/artemis/root
ENV PATH=/opt/artemis/bin:/opt/artemis/root/bin:${PATH}
ENV LD_LIBRARY_PATH=/opt/artemis/lib:/opt/artemis/lib64:/opt/artemis/root/lib
ENV CMAKE_PREFIX_PATH=/opt/artemis:/opt/artemis/root
ENV PKG_CONFIG_PATH=/opt/artemis/lib/pkgconfig:/opt/artemis/lib64/pkgconfig
ENV CFLAGS="-O2 -march=x86-64 -mtune=generic -mno-avx -mno-avx2"
ENV CXXFLAGS="-O2 -march=x86-64 -mtune=generic -mno-avx -mno-avx2"

SHELL ["/bin/bash", "-o", "pipefail", "-c"]

RUN dnf -y update && \
    dnf -y install dnf-plugins-core && \
    dnf config-manager --set-enabled crb && \
    dnf -y install \
      git gcc gcc-c++ gcc-gfortran make cmake ninja-build pkgconf-pkg-config \
      which findutils diffutils patch tar gzip bzip2 xz unzip \
      curl wget ca-certificates python3 python3-pip rsync \
      binutils file procps-ng tmux emacs vim \
      openssl-devel zlib-devel xz-devel bzip2-devel pcre2-devel \
      libX11-devel libXext-devel libXft-devel libXpm-devel libXrender-devel \
      libjpeg-turbo-devel libpng-devel freetype-devel giflib-devel \
      mesa-libGL-devel mesa-libGLU-devel \
      libuuid-devel sqlite-devel \
      openmpi openmpi-devel && \
    dnf clean all && rm -rf /var/cache/dnf

RUN mkdir -p \
      ${ARTEMIS_ROOT}/src \
      ${ARTEMIS_ROOT}/bin \
      ${ARTEMIS_ROOT}/include \
      ${ARTEMIS_ROOT}/lib \
      ${ARTEMIS_ROOT}/lib64 \
      ${ARTEMIS_ROOT}/scripts \
      /work/src /work/build /work/local /work/scripts && \
    chmod 1777 /work

RUN cd ${ARTEMIS_ROOT}/src && \
    git clone --depth 1 --branch ${ROOT_VERSION} https://github.com/root-project/root.git && \
    cmake -S root -B root-build \
      -DCMAKE_BUILD_TYPE=Release \
      -DCMAKE_INSTALL_PREFIX=${ROOTSYS} \
      -DCMAKE_C_FLAGS_RELEASE="-O2 -DNDEBUG -march=x86-64 -mtune=generic -mno-avx -mno-avx2" \
      -DCMAKE_CXX_FLAGS_RELEASE="-O2 -DNDEBUG -march=x86-64 -mtune=generic -mno-avx -mno-avx2" \
      -Dgnuinstall=ON \
      -Dtesting=OFF \
      -Dtmva=OFF \
      -Droofit=OFF \
      -Dpyroot=OFF \
      -Dwebgui=OFF \
      -Dxrootd=OFF \
      -Ddavix=OFF \
      -Dmysql=OFF \
      -Dpgsql=OFF \
      -Dodbc=OFF \
      -Dsqlite=ON \
      -Dssl=ON \
      -Dx11=ON \
      -Dopengl=ON && \
    cmake --build root-build -j${NPROC} && \
    cmake --install root-build

RUN cd ${ARTEMIS_ROOT}/src && \
    git clone --depth 1 --branch ${YAML_CPP_VERSION} https://github.com/jbeder/yaml-cpp.git && \
    cmake -S yaml-cpp -B yaml-cpp/build \
      -DCMAKE_BUILD_TYPE=Release \
      -DCMAKE_INSTALL_PREFIX=${ARTEMIS_ROOT} \
      -DCMAKE_INSTALL_LIBDIR=lib \
      -DYAML_BUILD_SHARED_LIBS=ON \
      -DYAML_CPP_BUILD_TESTS=OFF \
      -DYAML_CPP_BUILD_TOOLS=OFF && \
    cmake --build yaml-cpp/build -j${NPROC} && \
    cmake --install yaml-cpp/build

RUN cd ${ARTEMIS_ROOT}/src && \
    git clone --depth 1 --branch ${LIBZMQ_VERSION} https://github.com/zeromq/libzmq.git && \
    cmake -S libzmq -B libzmq/build \
      -DCMAKE_BUILD_TYPE=Release \
      -DCMAKE_INSTALL_PREFIX=${ARTEMIS_ROOT} \
      -DCMAKE_INSTALL_LIBDIR=lib \
      -DCMAKE_POSITION_INDEPENDENT_CODE=ON \
      -DBUILD_TESTS=OFF -DENABLE_DRAFTS=OFF && \
    cmake --build libzmq/build -j${NPROC} && \
    cmake --install libzmq/build

RUN cd ${ARTEMIS_ROOT}/src && \
    git clone --depth 1 --branch ${HIREDIS_VERSION} https://github.com/redis/hiredis.git && \
    make -C hiredis -j${NPROC} PREFIX=${ARTEMIS_ROOT} && \
    make -C hiredis PREFIX=${ARTEMIS_ROOT} install

RUN cd ${ARTEMIS_ROOT}/src && \
    git clone --depth 1 --branch ${REDIS_PLUS_PLUS_VERSION} https://github.com/sewenew/redis-plus-plus.git && \
    sed -i '/#include "cxx_utils.h"/i #include <cstdint>' redis-plus-plus/src/sw/redis++/utils.h && \
    cmake -S redis-plus-plus -B redis-plus-plus/build \
      -DCMAKE_BUILD_TYPE=Release \
      -DCMAKE_INSTALL_PREFIX=${ARTEMIS_ROOT} \
      -DCMAKE_INSTALL_LIBDIR=lib \
      -DCMAKE_PREFIX_PATH=${ARTEMIS_ROOT} \
      -DCMAKE_POSITION_INDEPENDENT_CODE=ON \
      -DREDIS_PLUS_PLUS_CXX_STANDARD=17 \
      -DREDIS_PLUS_PLUS_BUILD_TEST=OFF \
      -DREDIS_PLUS_PLUS_BUILD_STATIC=OFF && \
    cmake --build redis-plus-plus/build -j${NPROC} && \
    cmake --install redis-plus-plus/build

RUN cd ${ARTEMIS_ROOT}/src && \
    git clone --depth 1 --branch ${ARTEMIS_BRANCH} https://github.com/artemis-dev/artemis.git && \
    cmake -S artemis -B artemis/build \
      -DCMAKE_BUILD_TYPE=Release \
      -DCMAKE_INSTALL_PREFIX=${ARTEMIS_ROOT} \
      -DCMAKE_PREFIX_PATH="${ARTEMIS_ROOT};${ROOTSYS}" \
      -DBUILD_GET=OFF \
      -DBUILD_WITH_ZMQ=ON \
      -DBUILD_WITH_REDIS=ON && \
    cmake --build artemis/build -j${NPROC} --verbose && \
    cmake --install artemis/build

RUN cat > /etc/profile.d/artemis-container.sh <<'EOF'
export ARTEMIS_ROOT=/opt/artemis
export ROOTSYS=/opt/artemis/root
export PATH=/opt/artemis/bin:/opt/artemis/root/bin:${PATH}
export LD_LIBRARY_PATH=/opt/artemis/lib:/opt/artemis/lib64:/opt/artemis/root/lib${LD_LIBRARY_PATH:+:${LD_LIBRARY_PATH}}
export CMAKE_PREFIX_PATH=/opt/artemis:/opt/artemis/root${CMAKE_PREFIX_PATH:+:${CMAKE_PREFIX_PATH}}
export PKG_CONFIG_PATH=/opt/artemis/lib/pkgconfig:/opt/artemis/lib64/pkgconfig${PKG_CONFIG_PATH:+:${PKG_CONFIG_PATH}}
if [ -r /opt/artemis/bin/thisartemis.sh ]; then
  source /opt/artemis/bin/thisartemis.sh
fi
EOF

COPY scripts/ ${ARTEMIS_ROOT}/scripts/
RUN chmod -R a+rX ${ARTEMIS_ROOT}/scripts && \
    printf '%s\n' '/opt/artemis/lib' '/opt/artemis/lib64' '/opt/artemis/root/lib' \
      > /etc/ld.so.conf.d/artemis.conf && \
    ldconfig && \
    root-config --version && \
    test -x ${ARTEMIS_ROOT}/bin/artemis && \
    (${ARTEMIS_ROOT}/bin/artemis --help >/dev/null 2>&1 || true)

WORKDIR /work
CMD ["/bin/bash", "-l"]
