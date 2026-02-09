FROM ubuntu:22.04 AS builder

ARG DEBIAN_FRONTEND=noninteractive

RUN apt-get update && apt-get install -y \
    build-essential \
    cmake \
    g++ \
    wget \
    unzip \
    libopencv-dev \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /build

COPY CMakeLists.txt ./
COPY include/ ./include/
COPY src/ ./src/
COPY build_with_torch.sh ./

# Copy pre-downloaded LibTorch if available
COPY libtorch*.zip /build/ 2>/dev/null || true

RUN echo "Building with LibTorch support..." && \
    sed -i 's/\r$//' build_with_torch.sh && \
    # Extract LibTorch if pre-downloaded
    if ls /build/libtorch*.zip 1> /dev/null 2>&1; then \
        echo "✓ Using pre-downloaded LibTorch from host machine..." && \
        mkdir -p /build/build && \
        unzip -q /build/libtorch*.zip -d /build/build && \
        rm -f /build/libtorch*.zip; \
    fi && \
    bash build_with_torch.sh

FROM ubuntu:22.04 AS runtime-base

ARG DEBIAN_FRONTEND=noninteractive

RUN apt-get update && apt-get install -y \
    libopencv-core4.5d \
    libopencv-imgproc4.5d \
    libopencv-highgui4.5d \
    libopencv-videoio4.5d \
    libopencv-ml4.5d \
    libopencv-imgcodecs4.5d \
    libgomp1 \
    && rm -rf /var/lib/apt/lists/*

FROM runtime-base AS runtime

ARG USERNAME=coinuser
ARG USER_UID=1000
ARG USER_GID=1000

RUN groupadd --gid $USER_GID $USERNAME \
    && useradd --uid $USER_UID --gid $USER_GID -m $USERNAME \
    && usermod -aG video $USERNAME

RUN mkdir -p /app/bin /app/lib /app/data

COPY --from=builder /build/build/coin_counter /app/bin/
COPY --from=builder /build/build/camera_calibration /app/bin/
COPY --from=builder /build/build/train_acquisition /app/bin/
COPY --from=builder /build/build/train_svm /app/bin/

COPY --from=builder /build/build/libtorch/lib/ /app/lib/

ENV COIN_DATA_DIR=/app/data
ENV LD_LIBRARY_PATH=/app/lib
ENV PATH=/app/bin:$PATH

RUN chown -R $USERNAME:$USERNAME /app

WORKDIR /app

USER $USERNAME

LABEL org.opencontainers.image.title="Coin Counter C++"
LABEL org.opencontainers.image.description="OpenCV-based coin detection and classification system"
LABEL org.opencontainers.image.version="1.0"
LABEL org.opencontainers.image.authors="Coin Counter Team"

CMD ["coin_counter"]
