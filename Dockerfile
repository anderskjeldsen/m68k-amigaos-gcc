FROM amigadev/docker-base:latest
WORKDIR /root
COPY ./ ./

RUN export DEBIAN_FRONTEND=noninteractive && \
    apt update && \
    apt install -y lhasa && \
    rm -rf /var/lib/apt/lists/* && \
    make update && \
    make -j $(nproc) all && \
    make -j $(nproc) sdk=ahi && \
    make -j $(nproc) sdk=camd && \
    make -j $(nproc) sdk=cgx && \
    make -j $(nproc) sdk=guigfx && \
    make -j $(nproc) sdk=mui && \
    make -j $(nproc) sdk=mcc_betterstring && \
    make -j $(nproc) sdk=mcc_guigfx && \
    make -j $(nproc) sdk=mcc_nlist && \
    make -j $(nproc) sdk=mcc_texteditor && \
    make -j $(nproc) sdk=mcc_thebar && \
    make -j $(nproc) sdk=render && \
    make -j $(nproc) sdk=warp3d && \
    cd / && \
    rm -rf /root/amiga-gcc && \
    apt-get purge -y \
    autoconf \
    bison \
    flex \
    g++ \
    gcc \
    gettext \
    git \
    lhasa \
    libgmp-dev \
    libmpfr-dev \
    libmpc-dev \
    libncurses-dev \
    make \
    rsync \
    texinfo\
    wget \
    && apt-get -y autoremove

ENV PATH /opt/amiga/bin:$PATH

