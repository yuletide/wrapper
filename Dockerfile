# Use an x86_64 builder to run the NDK toolchain; configurable via ARG to satisfy linters
ARG NDK_HOST_PLATFORM=linux/amd64
FROM --platform=${NDK_HOST_PLATFORM} ubuntu:latest AS builder

# Install build dependencies
RUN apt-get update && apt-get install -y \
  aria2 \
  cmake \
  make \
  gcc-aarch64-linux-gnu \
  g++-aarch64-linux-gnu \
  curl \
  wget \
  unzip \
  lsb-release \
  software-properties-common \
  gnupg \
  && rm -rf /var/lib/apt/lists/*

# Set up Android NDK r23b
RUN aria2c -o /tmp/android-ndk-r23b-linux.zip https://dl.google.com/android/repository/android-ndk-r23b-linux.zip \
  && unzip -q -d /root /tmp/android-ndk-r23b-linux.zip \
  && rm /tmp/android-ndk-r23b-linux.zip

# Set environment variable for NDK
ENV ANDROID_NDK_PATH=/root/android-ndk-r23b
ENV HOME=/root

# Copy source code
WORKDIR /app
COPY . /app

# Build libpcre from source for Android arm64
RUN cd /tmp && \
    curl -L -o pcre-8.45.tar.gz "https://sourceforge.net/projects/pcre/files/pcre/8.45/pcre-8.45.tar.gz/download" && \
    tar -xzf pcre-8.45.tar.gz && \
    cd pcre-8.45 && \
    export CC="$HOME/android-ndk-r23b/toolchains/llvm/prebuilt/linux-x86_64/bin/aarch64-linux-android22-clang" && \
    export CXX="$HOME/android-ndk-r23b/toolchains/llvm/prebuilt/linux-x86_64/bin/aarch64-linux-android22-clang++" && \
    export AR="$HOME/android-ndk-r23b/toolchains/llvm/prebuilt/linux-x86_64/bin/llvm-ar" && \
    export RANLIB="$HOME/android-ndk-r23b/toolchains/llvm/prebuilt/linux-x86_64/bin/llvm-ranlib" && \
    ./configure --host=aarch64-linux-android --enable-shared --disable-static --prefix=/tmp/pcre-install && \
    make -j$(nproc) && \
    make install && \
    mkdir -p /app/rootfs/system/lib64 && \
    cp /tmp/pcre-install/lib/libpcre.so /app/rootfs/system/lib64/libpcre.so && \
    ls -lh /app/rootfs/system/lib64/libpcre.so

# Build the wrapper
RUN mkdir -p build && cd build \
  && cmake \
  -DCMAKE_C_COMPILER=/root/android-ndk-r23b/toolchains/llvm/prebuilt/linux-x86_64/bin/aarch64-linux-android22-clang \
  -DCMAKE_CXX_COMPILER=/root/android-ndk-r23b/toolchains/llvm/prebuilt/linux-x86_64/bin/aarch64-linux-android22-clang++ \
  .. \
  && make VERBOSE=1

# Final stage
# Final image matches the target runtime platform (arm64 for this branch)
ARG TARGETPLATFORM
FROM --platform=${TARGETPLATFORM} ubuntu:latest

WORKDIR /app
COPY --from=builder /app/wrapper /app/wrapper
COPY --from=builder /app/rootfs /app/rootfs

ENV args=""

CMD ["bash", "-c", "./wrapper ${args}"]

EXPOSE 10020 20020