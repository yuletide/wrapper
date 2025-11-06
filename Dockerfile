FROM ubuntu:latest AS builder

# Install build dependencies
RUN apt-get update && apt-get install -y \
  aria2 \
  cmake \
  make \
  gcc-aarch64-linux-gnu \
  g++-aarch64-linux-gnu \
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

# Build the wrapper
RUN mkdir -p build && cd build \
  && cmake \
       -DCMAKE_C_COMPILER=/root/android-ndk-r23b/toolchains/llvm/prebuilt/linux-x86_64/bin/aarch64-linux-android22-clang \
       -DCMAKE_CXX_COMPILER=/root/android-ndk-r23b/toolchains/llvm/prebuilt/linux-x86_64/bin/aarch64-linux-android22-clang++ \
       .. \
  && make VERBOSE=1

# Final stage
FROM ubuntu:latest

WORKDIR /app
COPY --from=builder /app/wrapper /app/wrapper
COPY --from=builder /app/rootfs /app/rootfs

ENV args=""

CMD ["bash", "-c", "./wrapper ${args}"]

EXPOSE 10020 20020