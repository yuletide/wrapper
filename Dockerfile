FROM ubuntu:latest AS builder

# Install build dependencies
RUN apt-get update && apt-get install -y \
    aria2 \
    cmake \
    gcc-aarch64-linux-gnu \
    wget \
    unzip \
    lsb-release \
    software-properties-common \
    gnupg \
    && rm -rf /var/lib/apt/lists/*

# Install LLVM
RUN wget https://apt.llvm.org/llvm.sh && chmod +x llvm.sh && ./llvm.sh && rm llvm.sh

# Set up Android NDK r23b
RUN aria2c -o /tmp/android-ndk-r23b-linux.zip https://dl.google.com/android/repository/android-ndk-r23b-linux.zip \
    && unzip -q -d /root /tmp/android-ndk-r23b-linux.zip \
    && rm /tmp/android-ndk-r23b-linux.zip

# Set environment variable for NDK
ENV ANDROID_NDK_PATH=/root/android-ndk-r23b

# Copy source code
WORKDIR /app
COPY . /app

# Build the wrapper
RUN mkdir -p build && cd build \
    && cmake .. \
    && make

# Final stage
FROM ubuntu:latest

WORKDIR /app
COPY --from=builder /app/wrapper /app/wrapper
COPY --from=builder /app/rootfs /app/rootfs

ENV args=""

CMD ["bash", "-c", "./wrapper ${args}"]

EXPOSE 10020 20020