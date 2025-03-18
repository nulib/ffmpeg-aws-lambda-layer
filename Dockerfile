#######################################
# Stage 1: Builder – compile libraries and ffmpeg statically
#######################################
FROM public.ecr.aws/amazonlinux/amazonlinux:2023 AS builder

RUN dnf update -y && \
    dnf install -y \
      autoconf \
      automake \
      bzip2 \
      bzip2-devel \
      cmake \
      diffutils \
      gcc \
      gcc-c++ \
      git \
      libtool \
      make \
      nasm \
      openssl-devel \
      pkgconfig \
      zlib-devel \
      wget \
      yasm && \
    dnf clean all

# Set up working directories and paths
WORKDIR /workspace
RUN mkdir -p ffmpeg_build sources bin
ENV PATH="/workspace/ffmpeg_build/bin:/workspace/bin:${PATH}"

#######################################
# Build libx264
#######################################
FROM builder AS x264
RUN cd sources && \
    git clone --depth 1 https://code.videolan.org/videolan/x264.git && \
    cd x264 && \
    ./configure --prefix=/workspace/ffmpeg_build --bindir=/workspace/bin --enable-static --disable-opencl && \
    make -j$(nproc) && \
    make install

#######################################
# Build libx265
#######################################
FROM builder AS x265
RUN cd sources && \
    git clone https://bitbucket.org/multicoreware/x265_git.git x265 || true && \
    cd x265/build/linux && \
    cmake -G "Unix Makefiles" -DCMAKE_INSTALL_PREFIX=/workspace/ffmpeg_build -DENABLE_SHARED=OFF ../../source && \
    make -j$(nproc) && \
    make install

#######################################
# Build libvpx
#######################################
FROM builder AS vpx
RUN cd sources && \
    git clone --depth 1 https://chromium.googlesource.com/webm/libvpx.git && \
    cd libvpx && \
    ./configure --prefix=/workspace/ffmpeg_build --disable-examples --disable-unit-tests --enable-vp9-highbitdepth --as=yasm --enable-static --disable-shared && \
    make -j$(nproc) && \
    make install

#######################################
# Build lame (libmp3lame)
#######################################
FROM builder AS lame
RUN cd sources && \
    wget -O lame.tar.gz https://downloads.sourceforge.net/project/lame/lame/3.100/lame-3.100.tar.gz && \
    tar xzf lame.tar.gz && \
    cd lame-3.100 && \
    ./configure --prefix=/workspace/ffmpeg_build --enable-nasm --disable-shared && \
    make -j$(nproc) && \
    make install

#######################################
# Build libopus
#######################################
FROM builder AS opus
RUN cd sources && \
    git clone --depth 1 https://github.com/xiph/opus.git && \
    cd opus && \
    ./autogen.sh && \
    ./configure --prefix=/workspace/ffmpeg_build --disable-shared && \
    make -j$(nproc) && \
    make install

#######################################
# Build libogg and libvorbis
#######################################
FROM builder AS vorbis
RUN cd sources && \
    wget -O libogg.tar.gz https://downloads.xiph.org/releases/ogg/libogg-1.3.5.tar.gz && \
    tar xzf libogg.tar.gz && \
    cd libogg-1.3.5 && \
    ./configure --prefix=/workspace/ffmpeg_build --disable-shared && \
    make -j$(nproc) && \
    make install && \
    cd .. && \
    wget -O libvorbis.tar.gz https://downloads.xiph.org/releases/vorbis/libvorbis-1.3.7.tar.gz && \
    tar xzf libvorbis.tar.gz && \
    cd libvorbis-1.3.7 && \
    ./configure --prefix=/workspace/ffmpeg_build --disable-shared && \
    make -j$(nproc) && \
    make install

#######################################
# Build ffmpeg with as much codec/format support as possible
#######################################
FROM builder AS ffmpeg_stage
COPY --from=x264 /workspace/ffmpeg_build /workspace/ffmpeg_build_x264
COPY --from=x265 /workspace/ffmpeg_build /workspace/ffmpeg_build_x265
COPY --from=vpx /workspace/ffmpeg_build /workspace/ffmpeg_build_vpx
COPY --from=lame /workspace/ffmpeg_build /workspace/ffmpeg_build_lame
COPY --from=opus /workspace/ffmpeg_build /workspace/ffmpeg_build_opus
COPY --from=vorbis /workspace/ffmpeg_build /workspace/ffmpeg_build_vorbis
RUN cp -r /workspace/ffmpeg_build_x264/* /workspace/ffmpeg_build && \
    cp -r /workspace/ffmpeg_build_x265/* /workspace/ffmpeg_build && \
    cp -r /workspace/ffmpeg_build_vpx/* /workspace/ffmpeg_build && \
    cp -r /workspace/ffmpeg_build_lame/* /workspace/ffmpeg_build && \
    cp -r /workspace/ffmpeg_build_opus/* /workspace/ffmpeg_build && \
    cp -r /workspace/ffmpeg_build_vorbis/* /workspace/ffmpeg_build

FROM ffmpeg_stage AS ffmpeg
ARG FFMPEG_VERSION=7.1
ENV PKG_CONFIG_PATH=/workspace/ffmpeg_build/lib/pkgconfig
RUN cd sources && \
    git clone --depth 1 --branch release/${FFMPEG_VERSION} https://git.ffmpeg.org/ffmpeg.git && \
    cd ffmpeg && \
    ./configure \
      --prefix=/workspace/ffmpeg_build \
      --pkg-config-flags="--static" \
      --extra-cflags="-I/workspace/ffmpeg_build/include" \
      --extra-ldflags="-L/workspace/ffmpeg_build/lib" \
      --extra-libs="-lpthread -lm" \
      --bindir=/workspace/bin \
      --enable-openssl \
      --enable-version3 \
      --enable-protocol=http \
      --enable-protocol=https \
      --enable-protocol=hls \
      --enable-gpl \
      --enable-libmp3lame \
      --enable-libopus \
      --enable-libvorbis \
      --enable-libvpx \
      --enable-libx264 \
      --enable-libx265 \
      --enable-static \
      --disable-shared && \
    make -j$(nproc) && \
    make install

#######################################
# Stage 2: Final image – copy static ffmpeg & ffprobe
#######################################
FROM public.ecr.aws/amazonlinux/amazonlinux:2023

COPY --from=ffmpeg /workspace/bin/ffmpeg /usr/local/bin/ffmpeg
COPY --from=ffmpeg /workspace/bin/ffprobe /usr/local/bin/ffprobe

RUN chmod +x /usr/local/bin/ffmpeg /usr/local/bin/ffprobe

ENTRYPOINT ["/bin/bash"]
CMD ["-c", "cp /usr/local/bin/ff* /output"]